import tkinter as tk
from tkinter import ttk, messagebox
import math
import winsound
import numpy as np
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure

NOTES = ["Đô (C)", "Đô# (C#)", "Rê (D)", "Rê# (D#)", "Mi (E)", "Fa (F)", "Fa# (F#)", "Son (G)", "Son# (G#)", "La (A)", "La# (A#)", "Si (B)"]
C0_FREQ = 16.351597831287414

class MusicPitchApp:
    def __init__(self, root):
        self.root = root
        self.root.title("MATLAB-Style Pitch Shifter & Waveform Analyzer (Time + Freq Domain)")
        # Tăng kích thước cửa sổ để chứa đủ 4 đồ thị rộng rãi
        self.root.geometry("1400x750") 
        
        # Colors (MATLAB Style)
        c_bg = '#F0F0F0'
        c_white = '#FFFFFF'
        c_blue = '#0072BD'
        c_orange = '#D95319'
        c_green = '#77AC30'
        c_gray = '#B0B0B0'
        
        self.root.configure(bg=c_bg)
        
        # --- Variables ---
        self.input_freq = tk.DoubleVar(value=440.0)
        self.shift_steps = tk.IntVar(value=2)
        
        self.input_note_var = tk.StringVar()
        self.output_freq_var = tk.StringVar()
        self.output_note_var = tk.StringVar()
        
        # --- Styling ---
        style = ttk.Style()
        style.theme_use('clam')
        
        style.configure('TLabel', background=c_white, font=('Segoe UI', 10))
        style.configure('Header.TLabel', background=c_white, font=('Segoe UI', 12, 'bold'), foreground=c_blue)
        style.configure('Value.TLabel', background=c_white, font=('Consolas', 12, 'bold'), foreground=c_orange)
        style.configure('Output.TLabel', background=c_white, font=('Consolas', 14, 'bold'), foreground=c_green)
        
        # --- Layout Main Frames ---
        main_frame = tk.Frame(root, bg=c_bg, padx=20, pady=20)
        main_frame.pack(fill='both', expand=True)
        
        control_frame = tk.Frame(main_frame, bg=c_bg)
        control_frame.pack(side='left', fill='y', padx=(0, 20))
        
        plot_frame = tk.Frame(main_frame, bg=c_white, highlightbackground=c_gray, highlightthickness=1)
        plot_frame.pack(side='right', fill='both', expand=True)
        
        def create_flat_button(parent, text, bg_color, command):
            btn = tk.Button(parent, text=text, font=('Segoe UI', 10, 'bold'), 
                            bg=bg_color, fg=c_white, activebackground=c_gray, activeforeground=c_white,
                            relief='flat', borderwidth=0, padx=15, pady=8, cursor="hand2", command=command)
            return btn

        # ==========================================
        # CONTROL PANELS (LEFT)
        # ==========================================
        # PANEL 1: INPUT
        panel1 = tk.Frame(control_frame, bg=c_white, highlightbackground=c_gray, highlightthickness=1, padx=25, pady=20)
        panel1.pack(fill='x', pady=(0, 15))
        ttk.Label(panel1, text="1. Original Signal (Tín hiệu gốc)", style='Header.TLabel').grid(row=0, column=0, sticky='w', pady=(0, 15), columnspan=3)
        ttk.Label(panel1, text="Input Frequency (Hz):").grid(row=1, column=0, sticky='w', pady=8)
        ttk.Entry(panel1, textvariable=self.input_freq, font=('Consolas', 12), width=12).grid(row=1, column=1, sticky='w', padx=15)
        ttk.Label(panel1, text="Detected Note:").grid(row=2, column=0, sticky='w', pady=8)
        ttk.Label(panel1, textvariable=self.input_note_var, style='Value.TLabel').grid(row=2, column=1, sticky='w', padx=15)
        btn_play1 = create_flat_button(panel1, "▶ Play", c_blue, self.play_input)
        btn_play1.grid(row=1, column=2, rowspan=2, padx=(10, 0))
        
        # PANEL 2: SHIFT
        panel2 = tk.Frame(control_frame, bg=c_white, highlightbackground=c_gray, highlightthickness=1, padx=25, pady=20)
        panel2.pack(fill='x', pady=15)
        ttk.Label(panel2, text="2. Pitch Shift Parameters", style='Header.TLabel').grid(row=0, column=0, sticky='w', pady=(0, 15), columnspan=2)
        ttk.Label(panel2, text="Shift Amount (Semitones):").grid(row=1, column=0, sticky='w', pady=8)
        ttk.Spinbox(panel2, from_=-24, to=24, textvariable=self.shift_steps, font=('Consolas', 12), width=10).grid(row=1, column=1, sticky='w', padx=15)
        tk.Label(panel2, text="* (+): Tăng nốt nhạc (Lên cao)\n* (-): Giảm nốt nhạc (Xuống trầm)", bg=c_white, fg='#777777', font=('Segoe UI', 9, 'italic'), justify='left').grid(row=2, column=0, columnspan=2, sticky='w', pady=(5,0))

        # PANEL 3: OUTPUT
        panel3 = tk.Frame(control_frame, bg=c_white, highlightbackground=c_gray, highlightthickness=1, padx=25, pady=20)
        panel3.pack(fill='x', pady=15)
        ttk.Label(panel3, text="3. Output Signal (Đầu ra)", style='Header.TLabel').grid(row=0, column=0, sticky='w', pady=(0, 15), columnspan=3)
        ttk.Label(panel3, text="Output Frequency (Hz):").grid(row=1, column=0, sticky='w', pady=8)
        ttk.Label(panel3, textvariable=self.output_freq_var, style='Output.TLabel').grid(row=1, column=1, sticky='w', padx=15)
        ttk.Label(panel3, text="Output Note:").grid(row=2, column=0, sticky='w', pady=8)
        ttk.Label(panel3, textvariable=self.output_note_var, style='Output.TLabel').grid(row=2, column=1, sticky='w', padx=15)
        btn_play2 = create_flat_button(panel3, "▶ Play", c_orange, self.play_output)
        btn_play2.grid(row=1, column=2, rowspan=2, padx=(10, 0))

        # ==========================================
        # PLOT PANEL (RIGHT) - 4 DIAGRAMS
        # ==========================================
        self.fig = Figure(figsize=(8, 6), dpi=100)
        self.fig.patch.set_facecolor(c_white)
        
        # 2x2 Grid
        self.ax1 = self.fig.add_subplot(221) # Hàng 1, Cột 1 (Time - In)
        self.ax2 = self.fig.add_subplot(222) # Hàng 1, Cột 2 (Freq - In)
        self.ax3 = self.fig.add_subplot(223) # Hàng 2, Cột 1 (Time - Out)
        self.ax4 = self.fig.add_subplot(224) # Hàng 2, Cột 2 (Freq - Out)
        
        self.fig.subplots_adjust(wspace=0.25, hspace=0.4, left=0.08, right=0.95, top=0.9, bottom=0.1)
        
        self.canvas = FigureCanvasTkAgg(self.fig, master=plot_frame)
        self.canvas.get_tk_widget().pack(fill='both', expand=True, padx=10, pady=10)

        # Binds
        self.input_freq.trace_add("write", self.calculate)
        self.shift_steps.trace_add("write", self.calculate)
        
        self.calculate()

    def get_note_info(self, f):
        if f <= 0: return "Invalid"
        n = 12 * math.log2(f / C0_FREQ)
        n_round = round(n)
        cents = (n - n_round) * 100
        note_name = NOTES[n_round % 12]
        octave = n_round // 12
        if abs(cents) <= 2: acc = "(Perfect Tune)"
        elif cents > 0: acc = f"(+{cents:.0f} cent)"
        else: acc = f"({cents:.0f} cent)"
        return f"{note_name}{octave} {acc}"

    def update_plot(self, f_in, f_out):
        """Hàm vẽ 4 đồ thị (2 Time Domain, 2 Frequency Domain)"""
        for ax in [self.ax1, self.ax2, self.ax3, self.ax4]:
            ax.clear()
            ax.set_facecolor('#F8F9FA')
            ax.grid(True, linestyle='--', alpha=0.6)
            ax.spines['top'].set_visible(False)
            ax.spines['right'].set_visible(False)
            ax.spines['left'].set_linewidth(1.2)
            ax.spines['bottom'].set_linewidth(1.2)
        
        # Sinh dữ liệu
        SAMPLE_RATE = 48000
        
        # 1. Dữ liệu miền Thời Gian (Time Domain) - Lấy 15ms để nhìn thấy sóng uốn lượn
        t_time = np.linspace(0, 0.015, 1000)
        y_in_time = np.sin(2 * np.pi * f_in * t_time)
        y_out_time = np.sin(2 * np.pi * f_out * t_time)
        
        # 2. Dữ liệu miền Tần Số (Freq Domain) - Lấy 100ms để phân giải FFT chính xác
        t_fft = np.arange(0, 0.1, 1/SAMPLE_RATE)
        y_in_fft = np.sin(2 * np.pi * f_in * t_fft)
        y_out_fft = np.sin(2 * np.pi * f_out * t_fft)
        
        win = np.hanning(len(t_fft))
        fft_in = np.abs(np.fft.rfft(y_in_fft * win)) / len(y_in_fft)
        fft_out = np.abs(np.fft.rfft(y_out_fft * win)) / len(y_out_fft)
        freqs = np.fft.rfftfreq(len(y_in_fft), 1.0 / SAMPLE_RATE)
        
        fft_in_db = 20 * np.log10(fft_in + 1e-12)
        fft_out_db = 20 * np.log10(fft_out + 1e-12)
        
        # Giới hạn trục X tự động cho FFT
        max_f = max(f_in, f_out)
        x_limit = max(2000, max_f * 1.5)

        # --- Đồ thị 1: Input Time Domain ---
        self.ax1.plot(t_time * 1000, y_in_time, color='#0072BD', linewidth=2)
        self.ax1.fill_between(t_time * 1000, y_in_time, 0, color='#0072BD', alpha=0.1)
        self.ax1.set_title(f'Time Domain - Input Signal', fontsize=11, fontweight='bold', loc='left')
        self.ax1.set_ylabel('Amplitude')
        self.ax1.set_xlim(0, 15)

        # --- Đồ thị 2: Input Frequency Domain ---
        self.ax2.plot(freqs, fft_in_db, color='#0072BD', linewidth=2)
        self.ax2.fill_between(freqs, fft_in_db, -80, color='#0072BD', alpha=0.2)
        self.ax2.axvline(x=f_in, color='#0072BD', linestyle=':', linewidth=1.5, alpha=0.6)
        self.ax2.set_title(f'Spectrum - Input ({f_in:.1f} Hz)', fontsize=11, fontweight='bold', loc='left')
        self.ax2.set_xlim(0, x_limit)
        self.ax2.set_ylim(-60, 0)

        # --- Đồ thị 3: Output Time Domain ---
        self.ax3.plot(t_time * 1000, y_out_time, color='#D95319', linewidth=2)
        self.ax3.fill_between(t_time * 1000, y_out_time, 0, color='#D95319', alpha=0.1)
        self.ax3.set_title(f'Time Domain - Output Signal', fontsize=11, fontweight='bold', loc='left')
        self.ax3.set_xlabel('Time (ms)')
        self.ax3.set_ylabel('Amplitude')
        self.ax3.set_xlim(0, 15)

        # --- Đồ thị 4: Output Frequency Domain ---
        self.ax4.plot(freqs, fft_out_db, color='#D95319', linewidth=2)
        self.ax4.fill_between(freqs, fft_out_db, -80, color='#D95319', alpha=0.2)
        self.ax4.axvline(x=f_out, color='#D95319', linestyle=':', linewidth=1.5, alpha=0.6)
        self.ax4.set_title(f'Spectrum - Output ({f_out:.1f} Hz)', fontsize=11, fontweight='bold', loc='left')
        self.ax4.set_xlabel('Frequency (Hz)')
        self.ax4.set_xlim(0, x_limit)
        self.ax4.set_ylim(-60, 0)
        
        self.canvas.draw()

    def calculate(self, *args):
        try:
            f_in = self.input_freq.get()
            steps = self.shift_steps.get()
            
            self.input_note_var.set(self.get_note_info(f_in))
            f_out = f_in * (2 ** (steps / 12.0))
            self.output_freq_var.set(f"{f_out:.2f} Hz")
            self.output_note_var.set(self.get_note_info(f_out))
            
            self.update_plot(f_in, f_out)
            
        except tk.TclError:
            pass

    def play_sound(self, freq):
        try:
            f = int(round(freq))
            if f < 37 or f > 32767:
                messagebox.showwarning("Warning", "Hardware limitation: 37Hz - 32kHz only.")
                return
            winsound.Beep(f, 1500) 
        except Exception as e:
            messagebox.showerror("Error", f"Could not play sound: {e}")

    def play_input(self):
        try: self.play_sound(self.input_freq.get())
        except: pass

    def play_output(self):
        try:
            f_out = self.input_freq.get() * (2 ** (self.shift_steps.get() / 12.0))
            self.play_sound(f_out)
        except: pass

if __name__ == "__main__":
    import ctypes
    try: ctypes.windll.shcore.SetProcessDpiAwareness(1)
    except: pass
    root = tk.Tk()
    app = MusicPitchApp(root)
    root.mainloop()
