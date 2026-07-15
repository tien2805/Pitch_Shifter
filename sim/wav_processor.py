import sys
import wave
import struct
import os

def wav_to_hex(wav_filename, hex_filename):
    if not os.path.exists(wav_filename):
        print(f"Error: {wav_filename} does not exist.")
        # Create a dummy silent wav if user doesn't have one
        print("Creating a dummy 1-second sine wave for testing...")
        create_dummy_wav(wav_filename)
        
    with wave.open(wav_filename, 'rb') as wav_file:
        n_channels = wav_file.getnchannels()
        sampwidth = wav_file.getsampwidth()
        n_frames = wav_file.getnframes()
        frames = wav_file.readframes(n_frames)
        
        if sampwidth != 2:
            print("Please provide a 16-bit PCM WAV file.")
            return

        with open(hex_filename, 'w') as hex_file:
            samples = struct.unpack(f"<{n_frames * n_channels}h", frames)
            
            for i in range(n_frames):
                if n_channels == 2:
                    left = samples[i*2]
                    right = samples[i*2 + 1]
                else:
                    left = samples[i]
                    right = samples[i]
                
                # Convert 16-bit signed to 24-bit signed (shift left 8)
                left_24 = (left << 8) & 0xFFFFFF
                right_24 = (right << 8) & 0xFFFFFF
                
                hex_file.write(f"{left_24:06X}{right_24:06X}\n")

def hex_to_wav(hex_filename, wav_filename, sample_rate=48000):
    if not os.path.exists(hex_filename):
        print(f"Error: {hex_filename} does not exist.")
        return
        
    with open(hex_filename, 'r') as hex_file:
        lines = hex_file.readlines()
        
    with wave.open(wav_filename, 'wb') as wav_file:
        wav_file.setnchannels(2) # Stereo
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(sample_rate)
        
        for line in lines:
            line = line.strip()
            if len(line) < 12:
                continue
            
            left_hex = line[0:6]
            right_hex = line[6:12]
            
            left_24 = int(left_hex, 16)
            right_24 = int(right_hex, 16)
            
            # Unsigned 24-bit to signed
            if left_24 >= 0x800000: left_24 -= 0x1000000
            if right_24 >= 0x800000: right_24 -= 0x1000000
            
            # 24-bit to 16-bit
            left_16 = left_24 >> 8
            right_16 = right_24 >> 8
            
            # Clamp
            left_16 = max(-32768, min(32767, left_16))
            right_16 = max(-32768, min(32767, right_16))
            
            data = struct.pack("<hh", left_16, right_16)
            wav_file.writeframesraw(data)

def create_dummy_wav(filename):
    import math
    with wave.open(filename, 'wb') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(48000)
        # 1-second 440Hz sine wave
        frames = []
        for i in range(48000):
            val = int(32767.0 * math.sin(2.0 * math.pi * 440.0 * i / 48000.0))
            frames.append(struct.pack("<h", val))
        wav_file.writeframes(b''.join(frames))

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage:")
        print("  python wav_processor.py encode input.wav input.txt")
        print("  python wav_processor.py decode output.txt output.wav")
    else:
        mode = sys.argv[1]
        file_in = sys.argv[2]
        file_out = sys.argv[3]
        if mode == 'encode':
            wav_to_hex(file_in, file_out)
            print(f"Encoded {file_in} to {file_out}")
        elif mode == 'decode':
            hex_to_wav(file_in, file_out)
            print(f"Decoded {file_in} to {file_out}")
