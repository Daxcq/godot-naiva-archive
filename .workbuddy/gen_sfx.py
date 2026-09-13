# -*- coding: utf-8 -*-
"""合成奶蛙档案馆 8-bit 搞笑音效包(全 ffmpeg,44.1kHz 16bit wav,零版权风险)。"""
import os, subprocess, shlex

FF = "ffmpeg"
OUT = r"C:/Users/wb198/Desktop/godot-naiva-archive/assets/audio"
os.makedirs(OUT, exist_ok=True)

# 每个: (文件名, aevalsrc 表达式, 时长秒, 额外后处理)
# 方波技巧: sin(2*PI*f*t)>0 ? A : -A ; 滑音: f(t) 线性变化需对相位积分, 用 (f0*t + k*t*t/2) 相位展开
JOBS = [
    # 街机开机: C5-E5-G5-C6 上电琶音, 方波, 每音 70ms, 末音拖 0.2s
    ("arcade_start.wav",
     "0.22*lt(sin(2*PI*523*t),0)+0.22*ge(sin(2*PI*523*t),0)".replace("523", "523"),
     None),
]

def square(freq, amp=0.22):
    return "(%s*if(gt(sin(2*PI*%s*t),0),1,-1))" % (amp, freq)

def note_square(freq, t0, t1, amp=0.22):
    # [t0,t1) 区间内的方波音符
    return "(between(t,%s,%s)*%s)" % (t0, t1, square(freq, amp))

def build_expr():
    exprs = []
    # 1) arcade_start: 523/659/784/1046 琶音
    parts = [note_square(523, 0, 0.07), note_square(659, 0.07, 0.14),
             note_square(784, 0.14, 0.21), note_square(1046, 0.21, 0.45)]
    exprs.append(("arcade_start.wav", "0.9*(" + "+".join(parts) + ")", 0.5))

    # 2) arcade_blip: 18ms 短哔 880Hz 方波 + 快速衰减
    exprs.append(("arcade_blip.wav",
                  "%s*exp(-18*t)" % square(880, 0.5), 0.06))

    # 3) arcade_score: 660->990 上扬双音(各 60ms), 第二音高八度感
    parts = [note_square(660, 0, 0.06), note_square(990, 0.06, 0.14)]
    exprs.append(("arcade_score.wav", "0.8*(" + "+".join(parts) + ")", 0.16))

    # 4) arcade_over: 滑落下坠 440->110 锯齿感(方波滑频), 相位 = 440t - 165/t? 用线性滑频积分: f(t)=440-550*t/0.6 -> 相位 440t-275t^2... 取 f0=440, k=-550: phase=2*PI*(440*t - 275*t*t/0.6/2*0)
    exprs.append(("arcade_over.wav",
                  "0.35*if(gt(sin(2*PI*(440*t-380*t*t))*sin(2*PI*(440*t-380*t*t)),0),1,-1)*exp(-2*t)", 0.6))

    # 5) npc_open: 叮咚 880->587 (E5->D5), 木鱼感加指数衰减
    parts = [note_square(880, 0, 0.09), note_square(587, 0.09, 0.22)]
    exprs.append(("npc_open.wav", "(" + "+".join(parts) + ")", 0.24))

    # 6) npc_blip: 动森式碎碎念——三小段随机音高(659/523/784), 各 45ms, 间隙 25ms, 方波
    parts = [note_square(659, 0.00, 0.045), note_square(523, 0.07, 0.115),
             note_square(784, 0.14, 0.185)]
    exprs.append(("npc_blip.wav", "0.7*(" + "+".join(parts) + ")", 0.2))

    # 7) npc_done: 道别上扬三连 C5-E5-G5 快速 + 末音衰减
    parts = [note_square(523, 0, 0.06), note_square(659, 0.06, 0.12),
             note_square(784, 0.12, 0.3)]
    exprs.append(("npc_done.wav", "(" + "+".join(parts) + ")", 0.32))

    # 8) boing: "胆子肥嘟嘟"弹簧——400->150Hz 下滑 + 25Hz 颤音 + 衰减
    exprs.append(("boing.wav",
                  "0.5*sin(2*PI*(400*t-250*t*t)+6*sin(2*PI*22*t))*exp(-4.5*t)", 0.55))

    # 9) moo_8bit: 8-bit 牛哞——低频 200->140->170 波浪滑音(牛叫的"哞~哞"起伏), 方波
    exprs.append(("moo_8bit.wav",
                  "0.4*if(gt(sin(2*PI*(200*t-40*t*t+30*sin(2*PI*3*t)*t))*sin(2*PI*(200*t-40*t*t+30*sin(2*PI*3*t)*t)),0),1,-1)*exp(-1.6*t)", 0.7))

    # 10) exit_fanfare: 胜利号角 C5-C5-C5-E5-G5-C6(马里奥式节奏), 方波+三角波混合
    parts = [note_square(523, 0.00, 0.09), note_square(523, 0.11, 0.20),
             note_square(523, 0.22, 0.31), note_square(659, 0.31, 0.48),
             note_square(784, 0.48, 0.65), note_square(1046, 0.65, 1.05)]
    exprs.append(("exit_fanfare.wav", "0.85*(" + "+".join(parts) + ")", 1.1))

    return exprs

def synth(name, expr, dur):
    out = os.path.join(OUT, name)
    dur_s = ("%0.2f" % dur)
    cmd = [FF, "-y", "-f", "lavfi", "-i",
           "aevalsrc='%s':s=44100:d=%s" % (expr, dur_s),
           "-af", "afade=t=out:st=%0.2f:d=0.05,lowpass=f=6500,volume=1.4" % max(0.0, dur - 0.06),
           "-ar", "44100", "-ac", "1", "-c:a", "pcm_s16le", out]
    r = subprocess.run(cmd, capture_output=True, text=True)
    ok = r.returncode == 0 and os.path.exists(out)
    print(("OK  " if ok else "FAIL") + " " + name, "" if ok else r.stderr[-260:])
    return ok

fails = 0
for name, expr, dur in build_expr():
    if not synth(name, expr, dur):
        fails += 1
print("DONE fails=%d" % fails)
