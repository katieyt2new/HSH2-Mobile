# Home Sheep Home 2: Android touch patch (unofficial)

Notes and a small touch-controls overlay for running your **own legally obtained copy**
of the desktop version of *Home Sheep Home 2* on Android.

**This repository contains no game files.** No SWF, no art, no sounds, no icons, no APK.
*Home Sheep Home 2* and its characters belong to Aardman Animations. This project is
unofficial and not affiliated with or endorsed by them. You need to supply the game yourself
(for example from your own Steam install), and you should keep any APK you build for your own device.

## What's here

| Path | What it is |
|---|---|
| `touch/TouchControls.as` | A small overlay (compiled to `touch.swf`) with on-screen LEFT / RIGHT / UP buttons. It sends ordinary arrow-key events, so game logic is untouched. Shows only while a level is on screen. |
| `build/application_android.template.xml` | AIR descriptor template for the APK. |

You provide three small arrow images named `left.png`, `right.png` and `up.png` (make your own) next to `TouchControls.as` before compiling.

## Tested on

Tested by hand on two phones (a 2018 mid-range Xiaomi and a low-end Samsung). Results vary by device.
Expect lower frame rates in the busiest levels.

## Requirements

- Your own copy of the desktop game's SWF and its `assets` folder
- [JPEXS Free Flash Decompiler (FFDec)](https://github.com/jindrapetrik/jpexs-decompiler)
- Harman AIR SDK **with compiler** (`amxmlc`) and `adt`, from airsdk.harman.com
- JDK 11 or newer, and the Android SDK (platform + build-tools) for `adt -platformsdk`

## 1. Patch the game SWF (in FFDec, P-code view)

Work on a **copy** of the SWF. Edit only the method bodies named below (the lines between `code` and `end ; code`);
leave the header numbers (`maxstack`, `localcount`, ...) alone. Save the pane, then File > Save as, reopen and re-check.

1. **`BuildSettings`**: change `isSteam` from `true` to `false` (`pushtrue` becomes `pushfalse`). This skips the desktop window and Steam code in `App.init`.
2. **`AIRCalls.createNativeWindow`**: replace the body with:
   ```
   getlocal0
   pushscope
   getlex QName(PackageNamespace("com.aardman.utils"),"SmartCache")
   callpropvoid QName(PackageNamespace(""),"init"), 0
   findpropstrict QName(PackageNamespace("flash.display"),"Loader")
   constructprop QName(PackageNamespace("flash.display"),"Loader"), 0
   coerce QName(PackageNamespace("flash.display"),"Loader")
   setlocal1
   getlocal1
   findpropstrict QName(PackageNamespace("flash.net"),"URLRequest")
   pushstring "app:/touch.swf"
   constructprop QName(PackageNamespace("flash.net"),"URLRequest"), 1
   callpropvoid QName(PackageNamespace(""),"load"), 1
   getlex QName(PackageNamespace(""),"stage")
   getlocal1
   callpropvoid QName(PackageNamespace(""),"addChild"), 1
   getlex QName(PackageNamespace(""),"stage")
   returnvalue
   ```
3. **`AIRCalls.centreNativeWindow`**: replace the body with:
   ```
   getlocal0
   pushscope
   returnvoid
   ```
4. **`Preloader` constructor**: the AIR build only starts its "continue" check from a loading event that never fires on Android.
   Add these lines (insert only, nothing deleted) just above the constructor's final `returnvoid`
   (below its label if it has one). Copy the `PrivateNamespace(null,"N")` number from the existing `checkFrame` lines in your file; it may not be `"1"`:
   ```
   findpropstrict QName(PackageNamespace(""),"addEventListener")
   getlex QName(PackageNamespace("flash.events"),"Event")
   getproperty QName(PackageNamespace(""),"ENTER_FRAME")
   getlocal0
   getproperty QName(PrivateNamespace(null,"1"),"checkContinue")
   callpropvoid QName(PackageNamespace(""),"addEventListener"), 2
   ```

Test on desktop before packaging:

```
adl -profile mobileDevice -screensize 1280x720:1280x720 application.xml
```

## 2. Compile the touch overlay

```
amxmlc -output touch.swf TouchControls.as
```

Settings at the top of `TouchControls.as`: button size and position, `LEVEL_ONLY`, `REPEAT_KEY_DOWN`,
`FORCE_QUALITY` (set to `""` to leave the game's own quality alone) and `SHOW_FPS`.

## 3. Package the APK

Create a signing key once, and **never commit it**:

```
adt -certificate -validityPeriod 25 -cn HSH2 2048-RSA cert.p12 <YOUR_PASSWORD>
```

```
adt -package -target apk-captive-runtime -storetype pkcs12 -keystore cert.p12 -storepass <YOUR_PASSWORD> HSH2.apk application_android.xml -platformsdk "<PATH_TO_ANDROID_SDK>" <PATCHED_GAME>.swf touch.swf assets
```

Add your own `icons` folder to the file list (and an `<icon>` block to the descriptor) if you want a custom launcher icon.

## Known issues

- Frame rate drops in the heaviest levels on older phones.
- The overlay's `LEVEL_ONLY` detection relies on the game's internal screen names; if the buttons never appear, set it to `false`.
- The `gpu` render mode caused drawing glitches on one phone in testing; `cpu` or a lower `FORCE_QUALITY` may help.

## Legal

The code and notes in this repository are offered as-is, for personal use with a copy of the game you own.
They do not grant any rights to the game itself.
