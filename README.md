# Recodesign

This script provides an easy way to codesign a DoubleDutch created event app. 

## Getting Started

This script is pretty simple in the end but there are a few requirements.

### Prerequisites

Required on local system for recodesign.sh script and for recodesigning process:

* Provisioning Profile for your app (must have push entitlement and associated domains)
* Distribution Certificate, with associated private key, in Keychain Access
	* We have found that this is often missed, especially in that the Certificate exists on the computer, but does not have associated private key.
* Up-to-date [Xcode](https://developer.apple.com/xcode/) and Xcode Command Line Tools installed (for PlistBuddy command)
* The .ipa that to be resigned will be provided by DoubleDutch.

### Some notes and explanations
* This script requires 2 arguments, it cannot run without both files.
* This app claims 2 specific entitlements: Apple's Push Notification Services, Associated Domains and Keychain Access. Push Notifications rely on a setting in the Provisioning profile
	* Push Notifications Services must be enabled on your Provisioning Profile for recodesigning to be successful
	* If the push notifications entitlement is not in the Provisioning Profile, this script will output the message "This provisioning profile doesn't have push entitlement!"
	* Associated Domains allow the DoubleDutch created app to open an associated DoubleDutch URLs.
	* Keychain Access is necessary to store the users login and password combination, so that the user can access the app, after closing and reopening, without re-logging in.

### Installing

Clone this repo or download the .zip
If you want the ultimate in convenience, put this repo in a safe place, then add to your $PATH

## Usage 

* Unzip the handoff folder that was sent to you.
* Launch terminal and run 'recodesign.sh' with minimum 2 arguments (The arguments can be run in any order.)
```
sh path/to/recodesign.sh path/to/app.ipa path/to/profile.mobileprovision
```

* There are several optional flags.
  * `e` For Enterprise Distribution (internal distribution, but not ad hoc)
  * `h` help
	* `t` enable TestFlight option in script (TestFlight is enabled by default)
	* `v` change the version and use a new provisioning profile
if using a flag use immediately after script name, you can use multiple flags
```
sh path/to/recodesign.sh -e path/to/app.ipa path/to/profile.mobileprovision
```
or 
```
sh path/to/recodesign.sh -etv path/to/app.ipa path/to/profile.mobileprovision
```
* When finished you will have a folder on your Desktop called 'Codesign_Output'. 
	* In this folder you will find the .ipa file ready to be submitted or distributed and the entitlements.plist file that was used in codesigning; this file can be helpful in troubleshooting. 
	* This folder will open automatically after the script has run.

### Example

An example of how this could look (file paths and names will vary):

```
sh recodesign.sh ~/Desktop/provided.ipa ~/Downloads/app.mobileprovision
```

## Acknowledgments

* credit to Tim Isganitis for initial motivation
* entitlements.plist idea - avinash dongarwar
* datecheck code credit - Kyle Blake Peters
* sha1 credit to Ingo Krabbe - https://gist.github.com/commandtab/2370710


