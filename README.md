# 🎬 codec-resolver — Universal Guide
### Batch Video Converter for DaVinci Resolve on Linux

---

> **Who this is for:** Anyone running DaVinci Resolve on Linux who gets "Media Offline",
> silent audio, or missing video when importing H.264/H.265/AAC footage.
> This guide works on **any Linux distribution**.

---

## Table of Contents

1. [The Problem — Why Resolve Breaks on Linux](#1-the-problem)
2. [The Solution — What This Script Does](#2-the-solution)
3. [Requirements — What You Need Installed](#3-requirements)
4. [Installation — One-Time Setup](#4-installation)
5. [Usage — How to Run the Script](#5-usage)
6. [Output Naming Convention](#6-output-naming-convention)
7. [Quality Profiles Explained](#7-quality-profiles-explained)
8. [Distro-Specific Notes](#8-distro-specific-notes)
9. [Troubleshooting](#9-troubleshooting)
10. [How the FFmpeg Command Works](#10-how-the-ffmpeg-command-works)
11. [Frequently Asked Questions](#11-frequently-asked-questions)
12. [References & Credits](#12-references--credits)

---

## 1. The Problem

DaVinci Resolve's **Linux target** is **Rocky Linux** (a Red Hat–based enterprise distro).
Blackmagic Design does **not** ship H.264, H.265, or AAC decoders in the Linux version
of Resolve — even Resolve Studio — because of patent/licensing restrictions.

This means that footage from:

| Source | Container | Video | Audio | Resolve on Linux |
|---|---|---|---|---|
| Smartphone / GoPro | `.mp4` | H.264 | AAC | ❌ Offline / Silent |
| Screen recorder (OBS) | `.mkv` | H.264 | AAC | ❌ Offline / Silent |
| YouTube download | `.webm` | VP9 | Opus | ❌ Offline |
| DSLR / mirrorless | `.mp4` | H.264 | AAC | ❌ Offline / Silent |
| H.265 / HEVC cameras | `.mp4` | H.265 | AAC | ❌ Offline |
| DNxHR / ProRes footage | `.mov` | DNxHR | PCM | ✅ Works natively |

**The root cause:** These codecs require patent licenses that Blackmagic does not bundle
on Linux. On Windows and macOS the OS provides those decoders; on Linux it does not.

---

## 2. The Solution

Transcode all footage **before** importing into DaVinci Resolve, converting it to formats
that Resolve reads natively on Linux:

| Property | Target Value |
|---|---|
| **Container** | MOV (QuickTime) |
| **Video codec** | DNxHR (Avid codec — no patent issues on Linux) |
| **DNxHR profile** | LB (default), or SQ / HQ / HQX / 444 |
| **Pixel format** | `yuv422p` (or `yuv444p` for 444 profile) |
| **Audio codec** | PCM signed 16-bit little-endian (`pcm_s16le`) |
| **Audio sample rate** | 48000 Hz (Resolve standard) |
| **Resolution** | Preserved (not re-scaled) |
| **Frame rate** | Preserved (not changed) |

The `convert-video` script in this folder does all of this automatically with a single command.

---

## 3. Requirements

### Must-have

| Tool | Purpose | Minimum version |
|---|---|---|
| `ffmpeg` | Video/audio encoding engine | 4.0+ |
| `ffprobe` | Input stream analyser (bundled with ffmpeg) | 4.0+ |
| `bash` | Script runtime | 4.0+ |

> `ffprobe` is **always** bundled together with `ffmpeg` — no separate install needed.

### FFmpeg must include the DNxHD/DNxHR encoder

The encoder is called `dnxhd` in FFmpeg. It has been part of the official ffmpeg build
since 2012. Any distro-packaged `ffmpeg` that is not stripped will include it.

Verify with:
```bash
ffmpeg -encoders 2>/dev/null | grep dnxhd
```
Expected output:
```
 VFS..D dnxhd                VC3/DNxHD
```
If you see output like this, you're good.

---

## 4. Installation

### Step 1 — Install FFmpeg

#### Arch Linux / Manjaro
```bash
sudo pacman -S ffmpeg
```

#### Ubuntu / Debian / Pop!_OS / Linux Mint
```bash
sudo apt update && sudo apt install ffmpeg
```

#### Fedora / RHEL / CentOS Stream
```bash
sudo dnf install ffmpeg
# If not in default repos, enable RPM Fusion first:
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install ffmpeg
```

#### openSUSE
```bash
sudo zypper install ffmpeg
```

#### Void Linux
```bash
sudo xbps-install -S ffmpeg
```

#### NixOS
```nix
# In configuration.nix:
environment.systemPackages = with pkgs; [ ffmpeg ];
```

#### Universal (any distro) — via Flatpak / Snap / Nix
If your distro's packaged ffmpeg is too old or stripped:
```bash
# Download a static ffmpeg build (no install needed)
wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar xf ffmpeg-release-amd64-static.tar.xz
sudo cp ffmpeg-*/ffmpeg ffmpeg-*/ffprobe /usr/local/bin/
```

---

### Step 2 — Place the script somewhere on your PATH

#### Option A — Per-user install (recommended, no sudo required)
```bash
mkdir -p ~/.local/bin
cp ~/codec-resolver/convert-video ~/.local/bin/convert-video
chmod +x ~/.local/bin/convert-video
```

Then make sure `~/.local/bin` is in your PATH. Add this to your `~/.bashrc` or `~/.zshrc`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```
Reload your shell:
```bash
source ~/.bashrc   # or source ~/.zshrc
```

#### Option B — System-wide install (available to all users)
```bash
sudo install -m 755 ~/codec-resolver/convert-video /usr/local/bin/convert-video
```

#### Option C — Run from this folder directly (no install)
```bash
~/codec-resolver/convert-video recording.mp4
```

---

### Step 3 — Verify installation
```bash
convert-video --help
```
You should see the banner and usage information.

---

## 5. Usage

### Basic syntax
```
convert-video [OPTIONS] <file1> [file2] [file3] ...
```

### Single file
```bash
convert-video recording.mp4
```

### Multiple files
```bash
convert-video recording1.mp4 recording2.mkv lecture.mov
```

### Files with spaces in their names (always quote them)
```bash
convert-video "my screen recording.mp4" "GoPro 2024-11-25.mp4"
```

### Wildcard — convert all MP4s in current folder
```bash
convert-video *.mp4
```

### Wildcard — convert all supported files
```bash
convert-video *.mp4 *.mkv *.mov *.webm
```

### Force overwrite existing output files
```bash
convert-video --force recording.mp4
```

### Choose a higher quality profile
```bash
convert-video --quality hq recording.mp4
```

### Combine options
```bash
convert-video --force --quality sq "clip 1.mkv" "clip 2.mp4"
```

---

## 6. Output Naming Convention

Output files are always placed **next to the original** in the same folder.
The original filename is preserved and `_resolve` is appended before the extension.

| Input file | Output file |
|---|---|
| `recording.mp4` | `recording_resolve.mov` |
| `lecture.mkv` | `lecture_resolve.mov` |
| `GoPro footage.mp4` | `GoPro footage_resolve.mov` |
| `/videos/raw/clip.webm` | `/videos/raw/clip_resolve.mov` |

> ✅ **Original files are never modified or deleted.**
> The script only creates new output files.

If the output file already exists, the script will **ask you before overwriting**.
Use `--force` to skip the prompt and overwrite automatically.

---

## 7. Quality Profiles Explained

Pass a profile with `--quality LEVEL` or `-q LEVEL`.

| Profile | Flag | Bit depth | Pixel Format | Approx. Bitrate @ 1080p | Use Case |
|---|---|---|---|---|---|
| **LB** (default) | `-q lb` | 8-bit | yuv422p | ~36 Mbps | Proxy editing, fast previews, storage-limited |
| **SQ** | `-q sq` | 8-bit | yuv422p | ~115 Mbps | Standard editorial work |
| **HQ** | `-q hq` | 8-bit | yuv422p | ~175 Mbps | High-quality offline editing |
| **HQX** | `-q hqx` | 12-bit | yuv422p | ~440 Mbps | HDR/high-precision grading |
| **444** | `-q 444` | 12-bit | yuv444p | ~730 Mbps | Full-chroma VFX / compositing |

> **Disk space note:** DNxHR files are large by design — they are intermediate/editing
> codecs optimised for editing performance, not storage efficiency.
> At HQ, 1 hour of 1080p footage ≈ ~75 GB.
> At LB, 1 hour of 1080p footage ≈ ~16 GB.

**Recommendation for most people:** Start with the default **LB** profile.
It is fast to encode and fast for Resolve to decode. Upgrade to SQ or HQ only
if you are grading with HDR, doing heavy colour work, or need every bit of quality.

---

## 8. Distro-Specific Notes

### Arch Linux / Manjaro
- Install from official repos: `sudo pacman -S ffmpeg`
- The official Arch `ffmpeg` package **always** includes DNxHD. No AUR needed.
- DaVinci Resolve itself can be installed from AUR: `paru -S davinci-resolve`
- If Resolve fails to launch after a system update, use the `resolve-fix` wrapper:
  ```bash
  git clone https://github.com/ChrisTitusTech/resolve-linux.git
  sudo install -m 755 resolve-linux/resolve-fix /usr/local/bin/resolve-fix
  resolve-fix   # launches Resolve with correct library preloads
  ```

### Ubuntu / Debian
- `apt install ffmpeg` gives you a complete ffmpeg with DNxHD.
- If you're on Ubuntu 20.04 LTS, ffmpeg 4.2 is in the repos — sufficient.
- For Ubuntu 18.04, add the `ppa:savoury1/ffmpeg4` PPA for a newer build.

### Fedora
- Fedora ships `ffmpeg-free` by default which may be missing some encoders.
- Install from **RPM Fusion** for a full build:
  ```bash
  sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
  sudo dnf install ffmpeg
  ```

### Pop!_OS / Linux Mint
- Same as Ubuntu — `sudo apt install ffmpeg` works fine.

### openSUSE Tumbleweed
- `sudo zypper install ffmpeg` from the multimedia repository.
- If DNxHD is missing, enable the Packman repository:
  ```bash
  sudo zypper addrepo -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman
  sudo zypper refresh && sudo zypper install ffmpeg
  ```

### NixOS
- Add to your `configuration.nix` or use `nix-env -iA nixpkgs.ffmpeg`.
- DNxHD is included in the nixpkgs ffmpeg package.

### Any distro — Static build (guaranteed to work)
If nothing else works, download a pre-compiled static ffmpeg binary:
```bash
wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar xf ffmpeg-release-amd64-static.tar.xz
sudo cp ffmpeg-*/ffmpeg ffmpeg-*/ffprobe /usr/local/bin/
```
This is a self-contained binary with no system dependencies.

---

## 9. Troubleshooting

### ❌ "Media Offline" in DaVinci Resolve
**Cause:** You are importing an H.264, H.265, or other unsupported codec directly.

**Fix:** Run the script on those files first, then import the `_resolve.mov` files.
```bash
convert-video your_clip.mp4
# Now import your_clip_resolve.mov into Resolve
```

---

### ❌ "Audio is silent" in DaVinci Resolve
**Cause:** The audio was encoded as AAC, which Resolve on Linux cannot decode.

**Fix:** Same as above — the script converts audio to PCM s16le at 48 kHz, which
Resolve reads natively on all platforms.

---

### ❌ "command not found: convert-video"
**Cause:** The script is not on your PATH.

**Fix:**
```bash
# Check if ~/.local/bin is in PATH:
echo $PATH | grep -o "$HOME/.local/bin"

# If not, add it:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Then install the script:
cp ~/codec-resolver/convert-video ~/.local/bin/convert-video
chmod +x ~/.local/bin/convert-video
```

---

### ❌ "ffmpeg build does not include the DNxHD/DNxHR encoder"
**Cause:** Your distro's ffmpeg was compiled without the DNxHD encoder
(rare, but happens on some minimal/stripped builds).

**Fix:**
```bash
# Arch:
sudo pacman -S ffmpeg

# Ubuntu/Debian:
sudo apt install ffmpeg

# Or use the static build:
wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar xf ffmpeg-release-amd64-static.tar.xz
sudo cp ffmpeg-*/ffmpeg ffmpeg-*/ffprobe /usr/local/bin/
```

---

### ❌ "ffprobe could not read the file"
**Cause:** The input file is corrupted, truncated, or uses a truly unsupported container.

**Fix:**
```bash
# Test the file manually with ffprobe:
ffprobe -v error -show_streams your_file.mp4

# Try playing it first to check it's not corrupted:
ffplay your_file.mp4
```

---

### ❌ Conversion failed with no clear message
**Cause:** Could be a codec, permissions, or disk space issue.

**Debug steps:**
```bash
# 1. Check disk space
df -h .

# 2. Run ffmpeg manually to see the full error:
ffmpeg -i your_file.mp4 \
  -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
  -c:v dnxhd -profile:v dnxhr_lb -pix_fmt yuv422p \
  -c:a pcm_s16le -ar 48000 \
  output_resolve.mov

# 3. Check file permissions:
ls -la your_file.mp4
```

---

### ❌ Output file is very large
**Expected.** DNxHR is an intermediate/editing codec — it trades file size for editing
performance and quality. A 3-second 1080p clip at LB is ~14 MB; that scales linearly.

For more compact output during proxy editing, use `-q lb` (the default). Once your
edit is locked, you can re-export from Resolve at a delivery codec (H.264/H.265).

---

### ❌ Resolve still shows "Media Offline" after converting
**Possible causes and fixes:**

1. **Wrong file imported** — Make sure you're importing `clip_resolve.mov`, not `clip.mp4`.
2. **Resolve project frame rate mismatch** — Check your project settings match the clip fps.
3. **Corrupted `.mov` output** — Run `ffprobe -v error clip_resolve.mov` to verify.
4. **Library launch problem on Arch** — Use the `resolve-fix` wrapper to launch Resolve:
   ```bash
   resolve-fix
   ```
   See: https://github.com/ChrisTitusTech/resolve-linux

---

## 10. How the FFmpeg Command Works

The core FFmpeg command the script runs for each file is:

```bash
ffmpeg \
  -hide_banner \
  -loglevel warning \
  -stats \
  -i "input.mp4" \
  -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
  -c:v dnxhd \
  -profile:v dnxhr_lb \
  -pix_fmt yuv422p \
  -c:a pcm_s16le \
  -ar 48000 \
  -movflags +faststart \
  "output_resolve.mov"
```

**Flag-by-flag explanation:**

| Flag | Meaning |
|---|---|
| `-hide_banner` | Suppress ffmpeg version/build info |
| `-loglevel warning` | Only show warnings and errors (not verbose codec info) |
| `-stats` | Show real-time encoding progress (fps, bitrate, time) |
| `-i "input.mp4"` | Input file |
| `-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2"` | Ensure width and height are even numbers (DNxHR requires this) |
| `-c:v dnxhd` | Use the DNxHD/DNxHR video encoder |
| `-profile:v dnxhr_lb` | Select the DNxHR Low Bandwidth profile |
| `-pix_fmt yuv422p` | 4:2:2 chroma subsampling, 8-bit depth |
| `-c:a pcm_s16le` | PCM audio, signed 16-bit, little-endian |
| `-ar 48000` | Resample audio to 48000 Hz (Resolve standard) |
| `-movflags +faststart` | Move MOV metadata to the front of the file (web-friendly, also good practice) |
| `"output_resolve.mov"` | Output file (MOV container = QuickTime, native to Resolve) |

**Why `trunc(iw/2)*2`?**
DNxHR and most video encoders require the frame dimensions to be divisible by 2.
If your source is an odd resolution (e.g. 1919×1079), this filter rounds it down to
the nearest even number (1918×1078) automatically without distorting the picture.

**Why PCM and not AAC or MP3?**
PCM is a raw, uncompressed audio format. It has no decoder dependencies — Resolve
(and every other professional tool) reads it natively on all platforms. AAC requires
a licensed decoder that Blackmagic does not bundle on Linux.

**Why 48000 Hz?**
48 kHz is the broadcast/professional standard. DaVinci Resolve's default project
audio sample rate is 48000 Hz. Matching this avoids any resampling artifacts during
the edit.

---

## 11. Frequently Asked Questions

**Q: Will this damage or delete my original files?**
No. The script only creates new `_resolve.mov` files. The originals are never touched.

---

**Q: Can I import the original file AND the converted file into Resolve?**
Yes. But only link/use the `_resolve.mov` file in your timeline. The original can stay
on disk for reference or re-conversion at a higher quality later.

---

**Q: Why not just use the FFmpeg Encoder Plugin for Resolve?**
The [ffmpeg_encoder_plugin](https://github.com/EdvinNilsson/ffmpeg_encoder_plugin) is an
**output/export** plugin for Resolve Studio — it lets you export H.264/H.265/AAC from
Resolve. It does **not** fix the input decode problem. You still need to transcode your
footage before importing if Resolve can't read it.

Both this script and that plugin are complementary tools, not alternatives.

---

**Q: What about ProRes? Can I use that instead of DNxHR?**
ProRes is a valid alternative if your ffmpeg has ProRes encoding support
(it does on most Linux builds). The command would use `-c:v prores_ks -profile:v 2`.
However, DNxHR is the recommended format because:
- It has explicit Resolve support documentation on Linux
- Avid's DNxHR has no patent issues with Linux builds
- The ChrisTitusTech and community-tested workflow uses DNxHR

---

**Q: My source footage is already DNxHR or ProRes — do I need to convert?**
No! If your source is already a Resolve-native format (`.mov` with DNxHR or ProRes,
`.mxf` with DNxHD, etc.), skip conversion and import directly into Resolve.

---

**Q: How do I know if my footage needs to be converted?**
Try importing it into Resolve. If it shows as:
- **Media Offline** — needs conversion (video codec unsupported)
- **Normal thumbnail but no audio** — needs conversion (AAC audio)
- **Normal thumbnail with audio** — no conversion needed

---

**Q: Can I batch-convert an entire folder?**
Yes, with shell globbing:
```bash
# All MP4s in current folder:
convert-video *.mp4

# All video files, multiple types:
convert-video *.mp4 *.mkv *.mov *.webm *.avi

# All MP4s recursively (requires bash find):
find /path/to/footage -name "*.mp4" -print0 | xargs -0 convert-video
```

---

**Q: Can I run this on macOS or Windows?**
- **macOS:** The script works on macOS with bash 4+ (install via Homebrew: `brew install bash ffmpeg`). However, macOS Resolve reads H.264/H.265/AAC natively, so you likely don't need it.
- **Windows:** Use WSL2 (Windows Subsystem for Linux) with this script. Native Windows would require a `.bat`/PowerShell rewrite.

---

**Q: Does this work with Resolve Free or only Resolve Studio?**
Both. The codec problem affects both Free and Studio on Linux. This script fixes the
input side for both versions. Studio does unlock more codec options, but AAC and H.264
input still have restrictions on Linux regardless of Free vs Studio.

---

## 12. References & Credits

| Resource | Link |
|---|---|
| Chris Titus — Resolve in Arch Linux | https://christitus.com/resolve-in-arch-linux/ |
| ChrisTitusTech/resolve-linux (convert script & fix wrapper) | https://github.com/ChrisTitusTech/resolve-linux |
| EdvinNilsson/ffmpeg_encoder_plugin (output plugin for Studio) | https://github.com/EdvinNilsson/ffmpeg_encoder_plugin |
| FFmpeg DNxHD/DNxHR encoder documentation | https://ffmpeg.org/ffmpeg-codecs.html#dnxhd |
| Blackmagic Supported Codec List (Linux) | https://documents.blackmagicdesign.com/SupportNotes/DaVinci_Resolve_20_Supported_Codec_List.pdf |
| Arch Linux Wiki — DaVinci Resolve | https://wiki.archlinux.org/title/DaVinci_Resolve |
| Static FFmpeg builds (all distros) | https://johnvansickle.com/ffmpeg/ |

---

## Quick Reference Card

```
╔════════════════════════════════════════════════════════╗
║           convert-video — Quick Reference              ║
╠════════════════════════════════════════════════════════╣
║  USAGE                                                 ║
║    convert-video [OPTIONS] file1 [file2 ...]           ║
║                                                        ║
║  COMMON EXAMPLES                                       ║
║    convert-video recording.mp4                         ║
║    convert-video *.mp4 *.mkv                           ║
║    convert-video --force clip.mp4                      ║
║    convert-video --quality hq clip.mp4                 ║
║                                                        ║
║  QUALITY PROFILES                                      ║
║    lb  (default) ~36 Mbps  — proxy / fast editing      ║
║    sq            ~115 Mbps — standard editorial        ║
║    hq            ~175 Mbps — high quality offline      ║
║    hqx           ~440 Mbps — 12-bit HDR grading        ║
║    444           ~730 Mbps — full-chroma VFX           ║
║                                                        ║
║  OUTPUT                                                ║
║    clip.mp4  →  clip_resolve.mov                       ║
║    Container: MOV | Video: DNxHR | Audio: PCM 48kHz   ║
║                                                        ║
║  INSTALL (one-time)                                    ║
║    cp ~/codec-resolver/convert-video ~/.local/bin/     ║
║    chmod +x ~/.local/bin/convert-video                 ║
╚════════════════════════════════════════════════════════╝
```

---

*Last updated: November 2026 · Tested on Arch Linux with DaVinci Resolve 21.1.1 and FFmpeg n9.1*
