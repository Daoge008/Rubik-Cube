import math
import struct
import wave
import random

def generate_gear_sound(output_path: str):
    sample_rate = 44100
    duration = 0.20  # 200 ms: snappy and immediate
    num_samples = int(sample_rate * duration)
    samples = [0.0] * num_samples

    random.seed(1337)

    # 5 tooth engagements during rotation (in seconds)
    # Rhythmic mechanical ratchet teeth succession
    teeth_times = [0.010, 0.042, 0.076, 0.112, 0.150]

    for i, t_start in enumerate(teeth_times):
        start_idx = int(t_start * sample_rate)
        is_final = (i == len(teeth_times) - 1)

        # 1. Subtle gear tooth sliding / friction before each engagement (12ms)
        friction_duration = 0.014
        friction_start = max(0, start_idx - int(friction_duration * sample_rate))
        for idx in range(friction_start, start_idx):
            progress = (idx - friction_start) / (start_idx - friction_start)
            # High-pass shaped friction noise
            noise = (random.random() * 2.0 - 1.0) * (progress ** 2.0) * 0.12
            samples[idx] += noise

        # 2. Tooth impact click
        decay = 160.0 if not is_final else 95.0
        amp = 0.50 if not is_final else 0.90

        # Metallic gear frequencies (harmonics of gear teeth vibration)
        if not is_final:
            # Lighter intermediate teeth
            freqs = [1250, 2600, 4200]
            weights = [0.45, 0.35, 0.20]
        else:
            # Heavier final detent / lock tooth
            freqs = [420, 1100, 2400, 3800]
            weights = [0.35, 0.30, 0.22, 0.13]

        impact_samples = int(sample_rate * (0.045 if not is_final else 0.065))
        for j in range(impact_samples):
            idx = start_idx + j
            if idx >= num_samples:
                break
            t = j / sample_rate
            env = math.exp(-decay * t)

            # Crisp transient impulse in first 1.5ms
            transient = 0.0
            if t < 0.0018:
                transient = (random.random() * 2.0 - 1.0) * math.exp(-1500.0 * t) * 0.75

            tone = sum(w * math.sin(2.0 * math.pi * f * t) for f, w in zip(freqs, weights))
            samples[idx] += (tone * 0.65 + transient * 0.35) * env * amp

    # Normalize to -0.5 dB peak
    max_val = max(abs(s) for s in samples) or 1.0
    target_peak = 29000.0
    scale = target_peak / max_val
    int_samples = [int(s * scale) for s in samples]

    with wave.open(output_path, 'w') as wf:
        wf.setnchannels(1)  # Mono
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(sample_rate)
        raw = struct.pack(f'<{len(int_samples)}h', *int_samples)
        wf.writeframes(raw)

    print(f"Generated {output_path} ({len(int_samples)} samples, {duration*1000:.0f}ms)")

if __name__ == '__main__':
    generate_gear_sound('assets/sounds/gear_turn.wav')
    generate_gear_sound('assets/sounds/cube_click.wav')
