# scrcpy_flutter

Scrcpy client base on flutter.

## Getting Started 
- Windows 
1. Use adb to push [server.jar](https://github.com/diyews/scrcpy/releases) to phone
    
    ``.\adb.exe push "C:\scrcpy-server-flutter.jar" /sdcard/scrcpy-server-flutter.jar``
    
1. Use adb to start server

    ``.\adb.exe shell CLASSPATH=/sdcard/scrcpy-server-flutter.jar nohup app_process / --nice-name=scrcpy_device_server com.genymobile.scrcpy.Server <16_length_key> error 0 8000000 0 -1 true - true true 0 false false - - false `>/dev/null 2`>`&1 `& ``
    
- Unix    
1. Use adb to push [server.jar](https://github.com/diyews/scrcpy/releases) to phone
    
    ``adb push ./scrcpy-server-flutter.jar /sdcard/scrcpy-server-flutter.jar``
    
1. Use adb to start server

    ``adb shell CLASSPATH=/sdcard/scrcpy-server-flutter.jar nohup app_process / --nice-name=scrcpy_device_server com.genymobile.scrcpy.Server <16_length_key> error 0 8000000 0 -1 true - true true 0 false false - - false >/dev/null 2>&1 & ``

Then you are able to connect to the phone via app.

## How does it work
App use tcp to connect to `scrcpy-server-flutter.jar`, server port `7007`.

Server use port `7008` to start http server for serving screenshot.
