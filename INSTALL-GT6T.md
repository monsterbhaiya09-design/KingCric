# KingCric Install Guide — Realme GT 6T

> Sirf **ONE APK** install karo. 2-2 APK mat try karo. GT 6T ke liye pehli choice **ARM64** wali hai.

## GT 6T ke liye kaunsi APK?

| APK | Size (exact) | Kab use karein |
|---|---|---|
| **ARM64** — `app-arm64-v8a-release.apk` | **19,855,072 bytes (18.9 MB)** | **Pehle ye try karo — GT 6T ke liye ye hi kaafi hai** |
| Universal — `app-release-universal.apk` | **54,093,963 bytes (51.6 MB)** | Sirf agar ARM64 na chale to |

> Size bilkul exact hona chahiye. Agar download ke baad size alag dikhe, to install MAT karo — file corrupt hai. Dobara download karo.

SHA256 (agar check karna ho):
- ARM64: `7e1877f4b0e65a3a3cc33b340c83c21cdf4d97ad77a2610640cd4ba8478f4c6d`
- Universal: `4fac67de89a3e655ce206bc52339759acf8cbdbda1afb180a6c644e4daa531f7`

---

## Step-by-step — GT 6T pe kaise install karein

### Step 1 — Purani files delete karo
1. Phone me **Files / My Files** kholo.
2. **Downloads** me jao.
3. Purani `KingCric` / `app-release` / `app-arm64` / `app-release-universal` wali sab files **delete** karo.
4. Agar **Settings → Apps → KingCric** dikhe, to usko **Uninstall** karo.

### Step 2 — Direct link se Chrome me download karo
1. Phone me **Chrome** kholo.
2. Assistant ne jo **direct link** diya hai (muse.ai wali link), usko Chrome me kholo.
3. **Download** dabao.
4. **WhatsApp ke andar se APK mat kholo.** WhatsApp pe file forward karke install mat karo — usse file kharab ho jaati hai.
5. Sirf **link ko text me** share karo, file ko forward mat karo.

### Step 3 — Size check karo (2 second ka kaam)
1. Download hone ke baad **Files → Downloads** me jao.
2. File pe lambi press / Details dekho.
3. Size check karo:
   - ARM64 = **18.9 MB (19,855,072 bytes)**
   - Universal = **51.6 MB (54,093,963 bytes)**
4. Size match nahi ho raha → install mat karo, dobara download karo aur size phir check karo.

### Step 4 — Install unknown apps allow karo
1. **Settings → Security / Privacy → Install unknown apps** pe jao.
   (Kuch Realme phones me: **Settings → Apps → Special app access → Install unknown apps**)
2. **Files** aur **Chrome** dono ke liye **Allow** kar do.

### Step 5 — Files se install karo (WhatsApp se NAHI)
1. **Files → Downloads** me jao.
2. APK pe tap karo.
3. **Install** dabao.
4. Agar **"Unknown developer" / "Install anyway"** aaye, to **Install anyway** dabao. Ye debug signature ki wajah se aata hai, Play Store wale build me nahi aayega.
5. Install hone ke baad **Open** dabao.

---

## Agar error aaye to kya karein?

### "App not installed" bas itna likha ho
1. Ghabrao mat. Pehle ye karo:
   - Phone ko **ek baar Restart** karo.
   - **Settings → Apps** me KingCric dikhe to **Uninstall** karo.
   - Downloads se purani file delete karke **dobara fresh download** karo (Chrome se, Files se install).
2. Phir bhi same error aaye to neeche wala **Report** section dekho.

### "App isn't compatible with your phone"
- Iska matlab purani APK thi jisme `uses-sdk` missing tha, ya WhatsApp viewer se install kar rahe the.
- Solution: **Nayi wali APK (upar wali table wali)** Chrome + Files se install karo. WhatsApp viewer se mat karo.

### "Failed to start several times / Clear now"
- Ye purani crash wali build me tha (`libdartjni.so` missing).
- Solution: Nayi wali APK install karo (usme ye fix hai). Agar nayi wali me bhi aaye to **Clear now** ek baar dabao, phir app kholo. Phir bhi aaye to Report karo.

### Phone me jagah (free space) kaise check karein
- **Settings → Storage** me dekho. **200 MB se zyada free** hona chahiye.
- Kam hai to kuch photos / videos delete ya move karo, phir try karo.

---

## Error report kaise bhejein? (Agar phir bhi na chale)

Assistant ko ye 4 cheezein bhejo:
1. **Phone:** Realme GT 6T
2. **Android version:** Settings → About phone → Android version (jaise Android 14) + Realme UI version
3. **Kaunsi APK:** ARM64 ya Universal + download ke baad **size kitna dikha** (screenshot best hai)
4. **Kahan se install kiya:** Files/Downloads se ya WhatsApp se + **exact error ka screenshot**

> Screenshot me poora error text dikhna chahiye. Sirf "nahi hua" likhne se pata nahi chalega kya hua.

---

## Quick checklist — Install se pehle

- [ ] Purani KingCric uninstall + purani APK files delete
- [ ] Chrome direct link se download (WhatsApp file forward NAHI)
- [ ] Size exact match (ARM64 18.9 MB / Universal 51.6 MB)
- [ ] Install unknown apps — Files + Chrome ke liye Allow
- [ ] Files → Downloads se install (WhatsApp viewer se NAHI)
- [ ] "Install anyway" aaye to dabao
