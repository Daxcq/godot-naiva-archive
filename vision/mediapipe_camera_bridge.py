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
# 每隔多少帧检查一次父进程是否还活着（约 2 秒一次）
PARENT_CHECK_INTERVAL = 60
_running = True


def _stop(*_args):
    """收到终止信号时干净退出，释放摄像头。"""
    global _running
    _running = False


def parent_alive() -> bool:
    """检查父进程是否还在。拿不到父进程信息时视为存活，避免误退出。"""
    if os.name != "nt":
        # 类 Unix：父进程被回收后会变成 1（init），此时说明原父进程已退出
        try:
            return os.getppid() != 1
        except OSError:
            return True
    try:
        import ctypes

        # 传 0 句柄即可查询；PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        kernel32 = ctypes.windll.kernel32
        handle = kernel32.OpenProcess(0x1000, False, os.getppid())
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

    model_path = resolve_model()
    cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
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

    print("[mediapipe-bridge] 摄像头已启动 -> udp 127.0.0.1:%d / %d"
          % (HAND_PORT, FRAME_PORT), flush=True)

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
                for a, b in [(0, 5), (5, 9), (9, 13), (13, 17), (0, 17),
                             (5, 8), (9, 12), (13, 16), (17, 20)]:
                    cv2.line(frame, (int(h[a].x * 640), int(h[a].y * 480)),
                             (int(h[b].x * 640), int(h[b].y * 480)), (125, 217, 255), 2)
                for p in h:
                    cv2.circle(frame, (int(p.x * 640), int(p.y * 480)), 4, (255, 243, 196), -1)

            hand_sock.sendto(json.dumps(payload).encode(), ("127.0.0.1", HAND_PORT))

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
        cap.release()
        detector.close()
        hand_sock.close()
        frame_sock.close()
        print("[mediapipe-bridge] 已释放摄像头并退出", flush=True)


if __name__ == "__main__":
    main()
