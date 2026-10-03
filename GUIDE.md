# Flutter Setup Assistant – User Guide

This app sets up everything you need to build Flutter apps on a Mac or
Windows computer. You click through six screens; it does the rest.

## Before you start

- **Internet connection.** The app downloads about 4 to 5 GB of tools.
- **Free disk space.** Keep at least 15 GB free.
- **Time.** 20 to 60 minutes depending on your connection. You can keep using
  your computer while it runs.
- **No administrator password is needed.** Everything is installed into your
  own user folder.
- **Already have some tools installed?** That is fine. The app finds them and
  only installs what is missing. It never deletes anything you already have.

## 1. Download

Open the download page:

**https://github.com/Umer9538/flutter-setup-assistant/releases/latest**

Under **Assets**, download the file for your computer:

| Computer | File |
|---|---|
| Mac (any model) | `FlutterSetupAssistant-macOS.zip` |
| Windows 10 or 11 | `FlutterSetupAssistant-Windows.zip` |

## 2. Open the app

### On a Mac

1. Double-click the downloaded zip. You get **Flutter Setup Assistant.app**.
2. Optional: drag it into your **Applications** folder.
3. **Right-click** (or Control-click) the app and choose **Open**.
4. A message says the developer cannot be verified. Click **Open** (or **Open Anyway**).

You only have to do the right-click step the first time. The message appears
because the app is not signed with a paid Apple developer certificate. It is
safe; the source code is public in the same GitHub repository.

If the dialog only shows "Move to Trash" with no Open button: open
**System Settings → Privacy & Security**, scroll down, and click
**Open Anyway** next to the message about Flutter Setup Assistant.

### On Windows

1. Right-click the downloaded zip and choose **Extract All…**. Keep all the
   extracted files together in one folder; the app needs the files next to it.
2. Open the folder and double-click **flutter_setup_assistant.exe**.
3. If a blue "Windows protected your PC" box appears, click **More info**, then
   **Run anyway**.

## 3. Walk through the six screens

The left side of the window shows where you are.

### Welcome
Shows what the app will do and where it will install. The suggested folder is
`development` inside your home folder. Leave it unless you have a reason to
change it. Avoid folders with spaces in the name. Click **Scan my computer**.

### Scan
The app looks for every tool and shows a status next to each one:

- **Ready** – already installed and compatible. Nothing will change.
- **Not installed** – will be installed.
- **Needs attention** – installed but incomplete; will be repaired.
- **Incompatible** – wrong version; a compatible copy is installed beside it.
  Your existing version is left alone.

Nothing is changed during the scan. Click **Review plan**.

### Plan
A list of exactly what will happen, with the versions chosen. Everything is
ticked by default. Untick anything you want to handle yourself. Items marked
**Manual step** (for example Xcode on a Mac) cannot be installed automatically
and are explained later. Click **Start installation**.

### Install
Each step shows a progress bar and a short description. The activity log at
the bottom shows the details.

Things to expect:

- **Mac: a system dialog may appear** asking to install the "command line
  developer tools". Click **Install**, accept Apple's license, and wait. The
  app continues automatically when it finishes.
- **Large downloads** (Flutter, Android Studio, the phone system image) each
  take several minutes. The progress bar shows megabytes downloaded.
- **Windows: nothing visible happens** during Git and VS Code installation.
  That is normal; they install silently.

If a step fails, the message explains why in plain language. The most common
cause is a dropped connection. Click **Back to plan**, then
**Start installation** again; finished downloads are reused.

When all steps are done, click **Run flutter doctor**.

### Diagnose
The app runs Flutter's own health check and translates the result:

- Green chips mean that area is fine.
- Each problem has a card with an explanation and, where possible, a
  **Fix automatically** button. Click it and the app repairs the problem and
  checks again.
- Some items are optional and only matter for certain kinds of apps:
  - **Xcode** (Mac) – only for iPhone and Mac apps. Install it from the App
    Store when you need it.
  - **Visual Studio** (Windows) – only for Windows desktop apps.
  - **Chrome** – only for web apps.
  You can build Android apps without any of these.

Click **Finish** when there are no red items left.

### Finish
Shows the next steps and the environment settings that were configured.

## 4. After the setup

1. **Open a new terminal window.** On a Mac, open **Terminal** (search for it
   with Spotlight). On Windows, open **PowerShell** from the Start menu. A
   *new* window is required; windows that were already open do not know about
   the new tools.
2. Check that Flutter responds:
   ```
   flutter --version
   ```
3. Create and run your first app:
   ```
   flutter create my_app
   cd my_app
   flutter emulators --launch Flutter_Pixel_7
   flutter run
   ```
   The first `flutter run` takes a few minutes while it builds. After that
   you will see the demo app on the virtual phone.
4. Or open the `my_app` folder in **Visual Studio Code** and press **F5**.

## Troubleshooting

**"flutter: command not found" in the terminal**
Open a *new* terminal window. If it still fails, run the assistant again,
leave only **Environment variables** ticked on the Plan screen, and start.

**The emulator does not start on Windows**
The emulator needs hardware virtualization. Open **Turn Windows features on
or off** from the Start menu, tick **Virtual Machine Platform** and
**Windows Hypervisor Platform**, click OK and restart.

**A download keeps failing**
Check that you are not on a network that blocks Google or GitHub downloads
(some office or school networks do). Try another network, then run the
installation again. Finished downloads are not repeated.

**The Mac says the app is damaged**
This happens when the zip was downloaded by some browsers. Open Terminal and
run:
```
xattr -dr com.apple.quarantine "/Applications/Flutter Setup Assistant.app"
```
Adjust the path if you put the app somewhere else, then open it again.

**Something else went wrong**
Every run writes a log file. Its location is shown at the bottom of the left
sidebar, in the folder `development/.setup-assistant/logs` inside your home
folder. Send that file to whoever gave you this app, along with a screenshot
of the error, and they can tell what happened.

## Questions people ask

**Does it need an administrator password?**
No. Everything is installed into your own user folder.

**Will it change or delete tools I already have?**
No. Existing tools are reused when they are compatible and left untouched when
they are not; a compatible copy is installed next to them. Your shell
settings file is backed up before it is edited, and the backup is kept in
`development/.setup-assistant/backups`.

**Can I run it again later?**
Yes. Running it again is safe. It only installs what is missing and can
repair a broken setup.

**How do I remove everything?**
Delete the `development` folder in your home folder, the
`Library/Android` folder (Mac) or `AppData\Local\Android` (Windows), and the
apps it installed (Android Studio, Visual Studio Code). Then remove the block
between the two lines mentioning "Flutter Environment Setup Assistant" in your
shell settings file (`~/.zprofile` on a Mac) or the environment variables on
Windows.
