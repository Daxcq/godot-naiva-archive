"""Laptop webcam + MediaPipe Hand Landmarker bridge for Godot.

由 scripts/visual_recognition.gd 在游戏启动时自动拉起，游戏退出时被回收。
手部状态发到 UDP 6401，带骨架标注的画面发到 UDP 6402。

额外保险：监听父进程（Godot），父进程一旦消失就自行退出。
这样即使 Godot 被强制结束（崩溃 / 任务管理器结束进程）没能回收本进程，
摄像头也不会被一直占着。
"""
import json
import os
import signal
import socket
import struct
import sys
from pathlib import Path

import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

# 模型随工程放在 vision/ 下（与 Godot 的 res://vision 对应）。
VISION_DIR = Path(__file__).resolve().parent
MODEL_CANDIDATES = [
    VISION_DIR / "hand_landmarker.task",
    VISION_DIR.parent / "public" / "models" / "hand_landmarker.task",
]

HAND_PORT = 6401
FRAME_PORT = 6402
# 每隔多少帧检查一次宿主进程是否还活着（约 2 秒一次）
PARENT_CHECK_INTERVAL = 60
# 宿主（Godot 游戏进程）PID 由 visual_recognition.gd 通过 argv 显式传入。
# 千万不能用 os.getppid() 判断宿主：venv 的 python.exe 是转发壳，桥代码跑在
# 它的子进程里，os.getppid() 拿到的是壳的 PID——壳永远活着，宿主死了桥也
# 不知道，于是产生僵尸桥（多桥抢摄像头/交错发帧 = 预览卡顿元凶）。
PARENT_PID = 0
if len(sys.argv) > 1:
    try:
        PARENT_PID = int(sys.argv[1])
    except ValueError:
        PARENT_PID = 0
# 桥接 PID 标记文件：游戏下次启动前据此清理本次残留（异常退出时来不及回收）。
PID_FILE = VISION_DIR / ".bridge.pid"
_running = True


def _stop(*_args):
    """收到终止信号时干净退出，释放摄像头。"""
    global _running
    _running = False


def parent_alive() -> bool:
    """检查宿主进程是否还在。拿不到宿主 PID 时视为存活，避免调试时误退出。"""
    if PARENT_PID <= 0:
        return True
    if os.name != "nt":
        try:
            os.kill(PARENT_PID, 0)
            return True
        except OSError:
            return False
    try:
        import ctypes

        # 传 0 句柄即可查询；PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        kernel32 = ctypes.windll.kernel32
        handle = kernel32.OpenProcess(0x1000, False, PARENT_PID)
        if not handle:
            return False
        try:
            code = ctypes.c_ulong()
            ok = kernel32.GetExitCodeProcess(handle, ctypes.byref(code))
            # STILL_ACTIVE = 259
            return bool(ok) and code.value == 259
        finally:
            kernel32.CloseHandle(handle)
    except Exception:
        return True


def write_pid_file() -> None:
    """记录壳进程与工作进程两个 PID，游戏下次启动前据此清场。"""
    try:
        PID_FILE.write_text("%d %d" % (os.getppid(), os.getpid()), encoding="ascii")
    except OSError:
        pass  # 导出 exe / 只读目录下写不进去就算了，清理是尽力而为


def clear_pid_file() -> None:
    try:
        PID_FILE.unlink()
    except OSError:
        pass


def d(a, b):
    return ((a.x - b.x) ** 2 + (a.y - b.y) ** 2) ** 0.5


def resolve_model() -> Path:
    for candidate in MODEL_CANDIDATES:
        if candidate.exists():
            return candidate
    raise SystemExit(
        "找不到 hand_landmarker.task，请放到 %s" % (VISION_DIR / "hand_landmarker.task")
    )


def main():
    signal.signal(signal.SIGINT, _stop)
    signal.signal(signal.SIGTERM, _stop)
    write_pid_file()

    model_path = resolve_model()
    cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
    # 640x480 保清晰度（用户反馈 320x240 太糊）；防卡顿靠 BUFFERSIZE=1 +
    # 接收端纹理复用/只解最新帧，这些优化已足够消除旧帧堆积的延迟。
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    # 关键：驱动缓冲只留 1 帧。旧帧在驱动层堆积是"画面延迟、越看越卡"的最大元凶。
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    if not cap.isOpened():
        raise SystemExit("无法打开笔记本摄像头")

    opts = vision.HandLandmarkerOptions(
        base_options=python.BaseOptions(model_asset_path=str(model_path)),
        num_hands=1,
        min_hand_detection_confidence=0.55,
        min_hand_presence_confidence=0.55,
        min_tracking_confidence=0.55,
    )
    detector = vision.HandLandmarker.create_from_options(opts)
    hand_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    frame_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    frame_id = 0

    print("[mediapipe-bridge] 摄像头已启动 (宿主PID=%d) -> udp 127.0.0.1:%d / %d"
          % (PARENT_PID, HAND_PORT, FRAME_PORT), flush=True)

    try:
        tick = 0
        while _running:
            tick += 1
            # 父进程（Godot）消失就自行退出，避免摄像头被残留进程长期占用。
            if tick % PARENT_CHECK_INTERVAL == 0 and not parent_alive():
                print("[mediapipe-bridge] 宿主进程已退出，桥接自行关闭", flush=True)
                break

            ok, frame = cap.read()
            if not ok:
                continue
            frame = cv2.flip(frame, 1)
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            result = detector.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb))

            payload = {"active": False, "x": .5, "y": .5, "grab": 0.,
                       "spread": .5, "confidence": 0.}
            if result.hand_landmarks:
                h = result.hand_landmarks[0]
                ring = [0, 5, 9, 13, 17]
                tips = [4, 8, 12, 16, 20]
                px = sum(h[i].x for i in ring) / 5
                py = sum(h[i].y for i in ring) / 5
                palm = max(d(h[0], h[9]), 1e-4)
                pinch = d(h[4], h[8]) / palm

                class _P:
                    pass

                center = _P()
                center.x, center.y = px, py
                spread = sum(d(h[i], center) for i in tips) / 5 / palm
                payload.update(
                    active=True, x=px, y=py,
                    grab=max(0., min(1., 1 - (pinch - .35) / .9)),
                    spread=max(0., min(1., (spread - .6) / 1.1)),
                    confidence=1.,
                )
                # 骨架坐标按实际帧尺寸算，别再硬编码 640x480。
                fh, fw = frame.shape[:2]
                for a, b in [(0, 5), (5, 9), (9, 13), (13, 17), (0, 17),
                             (5, 8), (9, 12), (13, 16), (17, 20)]:
                    cv2.line(frame, (int(h[a].x * fw), int(h[a].y * fh)),
                             (int(h[b].x * fw), int(h[b].y * fh)), (125, 217, 255), 2)
                for p in h:
                    cv2.circle(frame, (int(p.x * fw), int(p.y * fh)), 3, (255, 243, 196), -1)

            hand_sock.sendto(json.dumps(payload).encode(), ("127.0.0.1", HAND_PORT))

            # q75：与原生采集分辨率匹配的质量（用户要求保清晰度）。
            ok, enc = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 75])
            if ok:
                data = enc.tobytes()
                size = 1200
                total = (len(data) + size - 1) // size
                for i in range(total):
                    frame_sock.sendto(
                        struct.pack("!IHH", frame_id, i, total) + data[i * size:(i + 1) * size],
                        ("127.0.0.1", FRAME_PORT),
                    )
                frame_id = (frame_id + 1) & 0xFFFFFFFF
    except KeyboardInterrupt:
        pass
    finally:
        clear_pid_file()
        cap.release()
        detector.close()
        hand_sock.close()
        frame_sock.close()
        print("[mediapipe-bridge] 已释放摄像头并退出", flush=True)


if __name__ == "__main__":
    main()
