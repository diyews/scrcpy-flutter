# scrcpy_flutter

Scrcpy client base on flutter.

## Getting Started 
*Note: 16-char-key is requried for AES encryption if you need sceenshot feature, otherwise provide any string(16-char) while starting server.*


- Windows 

1. Use adb to push [server.jar](https://github.com/diyews/scrcpy/releases) to phone
    
        .\adb.exe push "C:\scrcpy-server-flutter.jar" /sdcard/scrcpy-server-flutter.jar
    
1. Use adb to start server (Replace `<16_char_key>` to your own)
    
    <details>
        <summary>Click to expand!</summary>
    
      ``.\adb.exe shell CLASSPATH=/sdcard/scrcpy-server-flutter.jar nohup app_process / --nice-name=scrcpy_device_server com.genymobile.scrcpy.Server <16_char_key> error 0 8000000 0 -1 true - true true 0 false false - - false `>/dev/null 2`>`&1 `& ``
    
    (Above `powershell.exe` use `` ` `` to escape character, in `cmd.exe` it is `` ^ ``)
    </details>
    
- Unix    
1. Use adb to push [server.jar](https://github.com/diyews/scrcpy/releases) to phone
    
        adb push ./scrcpy-server-flutter.jar /sdcard/scrcpy-server-flutter.jar
    
1. Use adb to start server (Replace `<16_char_key>` to your own)

    ``adb shell CLASSPATH=/sdcard/scrcpy-server-flutter.jar nohup app_process / --nice-name=scrcpy_device_server com.genymobile.scrcpy.Server <16_char_key> error 0 8000000 0 -1 true - true true 0 false false - - false >/dev/null 2>&1 & ``

Then you are able to connect to the phone via app.

## How this app works
App use tcp to connect to `scrcpy-server-flutter.jar`, server port `7007`.

Server use port `7008` to start http server for serving screenshot.

## Trouble shooting

1. Server didn't start. 

    You can check if server is running by typing `adb shell "ps -A | grep scrcpy_device_server"`

    Try to run command in the front to check if errors there whiling start server. (remove `nohup`, `&` and output redirect from the start script)
    
    `adb shell CLASSPATH=/sdcard/scrcpy-server-flutter.jar nohup app_process / --nice-name=scrcpy_device_server com.genymobile.scrcpy.Server <16_char_key> error 0 8000000 0 -1 true - true true 0 false false - - false`
  
