import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import math
import winsound
import numpy as np
import wave
import struct
import os
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure

class VoiceTransformerApp:
    def __init__(self, root):
        self.root = root
        self.root.title("FPGA CORDIC Voice Transformer - Hardware Simulator")
        self.root.geometry("1400x800") 
        
        # Colors (MATLAB Style)
        c_bg = '#F0F0F0'
        c_white = '#FFFFFF'
        c_blue = '#0072BD'
        c_orange = '#D95319'
        c_gray = '#B0B0B0'
        
        self.root.configure(bg=c_bg)
        
        # Variables
        self.shift_freq = tk.DoubleVar(value=1000.0)
        self.wav_filepath = None
        self.processed_filepath = "temp_processed.wav"
        self.wav_name = tk.StringVar(value="(Chưa tải file)")
        
        # Styling
        style = ttk.Style()
        style.theme_use('clam')
        style.configure('TLabel', background=c_white, font=('Segoe UI', 10))
        style.configure('Header.TLabel', background=c_white, font=('Segoe UI', 12, 'bold'), foreground=c_blue)
        
        # Layout Frames
        main_frame = tk.Frame(root, bg=c_bg, padx=20, pady=20)
        main_frame.pack(fill='both', expand=True)
        
        control_frame = tk.Frame(main_frame, bg=c_bg)
        control_frame.pack(side='left', fill='y', padx=(0, 20))
        
        plot_frame = tk.Frame(main_frame, bg=c_white, highlightbackground=c_gray, highlightthickness=1)
        plot_frame.pack(side='right', fill='both', expand=True)
        
        def create_flat_button(parent, text, bg_color, command, width=15):
            return tk.Button(parent, text=text, font=('Segoe UI', 10, 'bold'), 
                             bg=bg_color, fg=c_white, activebackground=c_gray, activeforeground=c_white,
                             relief='flat', borderwidth=0, padx=10, pady=8, cursor="hand2", width=width, command=command)

        # ==========================================
        # CONTROL PANELS (LEFT)
        # ==========================================
        
        # PANEL 1: INPUT AUDIO
        panel1 = tk.Frame(control_frame, bg=c_white, highlightbackground=c_gray, highlightthickness=1, padx=25, pady=20)
        panel1.pack(fill='x', pady=(0, 15))
        ttk.Label(panel1, text="1. Original Audio (Tín hiệu gốc)", style='Header.TLabel').pack(anchor='w', pady=(0, 10))
        
        btn_load = create_flat_button(panel1, "📂 Load WAV File", "#607D8B", self.load_wav)
        btn_load.pack(anchor='w', pady=5)
        
        ttk.Label(panel1, textvariable=self.wav_name, font=('Segoe UI', 9, 'italic')).pack(anchor='w', pady=(0, 15))
        
        btn_play1 = create_flat_button(panel1, "▶ Play Original", c_blue, self.play_input)
        btn_play1.pack(anchor='w')
        
        # PANEL 2: CORDIC SETTINGS
        panel2 = tk.Frame(control_frame, bg=c_white, highlightbackground=c_gray, highlightthickness=1, padx=25, pady=20)
        panel2.pack(fill='x', pady=15)
        ttk.Label(panel2, text="2. CORDIC Shift Frequency", style='Header.TLabel').pack(anchor='w', pady=(0, 10))
        
        freq_frame = tk.Frame(panel2, bg=c_white)
        freq_frame.pack(anchor='w', pady=5)
        ttk.Label(freq_frame, text="Frequency (Hz):").pack(side='left', padx=(0, 10))
        ttk.Spinbox(freq_frame, from_=100, to=4000, increment=100, textvariable=self.shift_freq, font=('Consolas', 12), width=8).pack(side='left')
        
        tk.Label(panel2, text="* Mô phỏng phép nhân Audio × cos(θ)\n* Tạo ra hiệu ứng Giọng Robot/Alien", bg=c_white, fg='#777777', font=('Segoe UI', 9, 'italic'), justify='left').pack(anchor='w', pady=(10,0))

        # PANEL 3: OUTPUT AUDIO
        panel3 = tk.Frame(control_frame, bg=c_white, highlightbackground=c_gray, highlightthickness=1, padx=25, pady=20)
        panel3.pack(fill='x', pady=15)
        ttk.Label(panel3, text="3. Processed Audio (Đầu ra)", style='Header.TLabel').pack(anchor='w', pady=(0, 10))
        
        btn_process = create_flat_button(panel3, "⚙️ Apply CORDIC Effect", "#4CAF50", self.process_audio)
        btn_process.pack(anchor='w', pady=(0, 15))
        
        btn_play2 = create_flat_button(panel3, "▶ Play Processed", c_orange, self.play_output)
        btn_play2.pack(anchor='w')
        
        btn_stop = create_flat_button(panel3, "⏹ Stop Audio", "#F44336", self.stop_audio)
        btn_stop.pack(anchor='w', pady=(15, 0))

        # ==========================================
        # PLOT PANEL (RIGHT)
        # ==========================================
        self.fig = Figure(figsize=(9, 7), dpi=100)
        self.fig.patch.set_facecolor(c_white)
        
        self.ax1 = self.fig.add_subplot(211) # Time Domain
        self.ax2 = self.fig.add_subplot(212) # Frequency Domain
        self.fig.subplots_adjust(hspace=0.4, left=0.1, right=0.95, top=0.9, bottom=0.1)
        
        self.canvas = FigureCanvasTkAgg(self.fig, master=plot_frame)
        self.canvas.get_tk_widget().pack(fill='both', expand=True, padx=10, pady=10)

        self.reset_plots()

    def reset_plots(self):
        for ax in [self.ax1, self.ax2]:
            ax.clear()
            ax.set_facecolor('#F8F9FA')
            ax.grid(True, linestyle='--', alpha=0.6)
            ax.spines['top'].set_visible(False)
            ax.spines['right'].set_visible(False)
        self.ax1.set_title("Time Domain Waveform", loc='left', fontweight='bold')
        self.ax2.set_title("Frequency Spectrum (FFT)", loc='left', fontweight='bold')
        self.canvas.draw()

    def load_wav(self):
        filepath = filedialog.askopenfilename(title="Chọn file âm thanh WAV", filetypes=[("WAV files", "*.wav")])
        if filepath:
            self.wav_filepath = filepath
            filename = os.path.basename(filepath)
            self.wav_name.set(f"Loaded: {filename}")
            messagebox.showinfo("Success", "Đã tải file WAV thành công!\nBấm 'Apply CORDIC Effect' để xử lý.")

    def process_audio(self):
        if not self.wav_filepath:
            messagebox.showwarning("Warning", "Vui lòng Load một file WAV trước!")
            return
            
        try:
            # Read WAV
            with wave.open(self.wav_filepath, 'rb') as wf:
                framerate = wf.getframerate()
                nchannels = wf.getnchannels()
                sampwidth = wf.getsampwidth()
                nframes = wf.getnframes()
                raw_data = wf.readframes(nframes)
                
            if sampwidth == 2:
                fmt = f"<{nframes * nchannels}h"
            else:
                messagebox.showerror("Error", "Chỉ hỗ trợ file WAV 16-bit PCM.")
                return
                
            samples = np.array(struct.unpack(fmt, raw_data), dtype=float)
            
            # Convert to mono for simple processing
            if nchannels == 2:
                samples = (samples[0::2] + samples[1::2]) / 2.0
                
            # --- CORDIC Amplitude Modulation Simulation ---
            shift_f = self.shift_freq.get()
            t = np.arange(len(samples)) / framerate
            carrier = np.cos(2 * np.pi * shift_f * t)
            
            # Processed = Audio * cos(theta)
            processed_samples = samples * carrier
            
            # Save to temporary file
            out_samples = np.clip(processed_samples, -32768, 32767).astype(np.int16)
            with wave.open(self.processed_filepath, 'wb') as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)
                wf.setframerate(framerate)
                wf.writeframes(out_samples.tobytes())
                
            # --- Update Plots ---
            self.update_plot(samples, processed_samples, framerate)
            messagebox.showinfo("Success", f"Đã xử lý xong!\nGiọng nói đã bị dịch đi {shift_f} Hz.\nHãy bấm 'Play Processed' để nghe.")
            
        except Exception as e:
            messagebox.showerror("Error", f"Lỗi xử lý âm thanh: {e}")

    def update_plot(self, in_data, out_data, fs):
        self.reset_plots()
        
        # Lấy 1 đoạn nhỏ 20ms để vẽ Time Domain cho rõ
        samples_to_show = int(fs * 0.02)
        t = np.arange(samples_to_show) / fs * 1000 # ms
        
        self.ax1.plot(t, in_data[:samples_to_show], color='#0072BD', alpha=0.5, label='Original Audio')
        self.ax1.plot(t, out_data[:samples_to_show], color='#D95319', linewidth=1.5, label='CORDIC Output')
        self.ax1.set_xlabel('Time (ms)')
        self.ax1.set_ylabel('Amplitude')
        self.ax1.legend()
        
        # Lấy 1 giây để phân tích FFT
        fft_len = min(len(in_data), fs)
        win = np.hanning(fft_len)
        fft_in = np.abs(np.fft.rfft(in_data[:fft_len] * win))
        fft_out = np.abs(np.fft.rfft(out_data[:fft_len] * win))
        freqs = np.fft.rfftfreq(fft_len, 1.0 / fs)
        
        self.ax2.plot(freqs, 20*np.log10(fft_in+1), color='#0072BD', alpha=0.7, label='Spectrum - Original')
        self.ax2.plot(freqs, 20*np.log10(fft_out+1), color='#D95319', alpha=0.7, label='Spectrum - Processed')
        self.ax2.set_xlabel('Frequency (Hz)')
        self.ax2.set_ylabel('Magnitude (dB)')
        self.ax2.set_xlim(0, 4000) # Chỉ xem dải giọng nói 0-4kHz
        self.ax2.legend()
        
        self.canvas.draw()

    def play_input(self):
        if self.wav_filepath:
            winsound.PlaySound(self.wav_filepath, winsound.SND_FILENAME | winsound.SND_ASYNC)
        else:
            messagebox.showwarning("Warning", "Chưa tải file WAV!")

    def play_output(self):
        if os.path.exists(self.processed_filepath):
            winsound.PlaySound(self.processed_filepath, winsound.SND_FILENAME | winsound.SND_ASYNC)
        else:
            messagebox.showwarning("Warning", "Chưa có file âm thanh đầu ra. Hãy bấm Apply CORDIC Effect trước!")
            
    def stop_audio(self):
        winsound.PlaySound(None, winsound.SND_PURGE)

if __name__ == "__main__":
    import ctypes
    try: ctypes.windll.shcore.SetProcessDpiAwareness(1)
    except: pass
    root = tk.Tk()
    app = VoiceTransformerApp(root)
    root.mainloop()
