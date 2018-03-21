#!/bin/sh 
# This script was written by Kyle Louis at DoubleDutch
# Resigning DoubleDutch created ios apps, here we go!
# This script requires the path to the .ipa file provided by DoubleDutch
# This script requires the path to the provisioning profile
# pass all the arguments in any order

function info {             # print an info log
  printf "\033[32m==> %s\033[0m\n" "$1"
}

function error {            # print an error log
  printf "\033[31m==> %s\033[0m\n" "$1"
  exit 1
}

function prompt {             # print an info log
  printf "\033[34m==> %s\033[0m\n" "$1"
}
info "This is version 2.0.0"
info "If you run into issues, please take screenshots of your terminal window and share with DoubleDutch."


while getopts "ehtv" opt; do
case "$opt" in
	e)
		enterpriseOpt=true
		info "Enterprise Distribution option enabled."
		shift 1
		;;
  h)
		info 'This script requires 2 arguments.
		The .ipa that DoubleDutch has sent and the provisioning profile.
		an example might look like this:
		sh recodesign.sh ~/Desktop/provided.ipa ~/Downloads/app.mobileprovision

		There are additional flags you can use.
		-h help (show this dialog)
		-t enable TestFlight option in script (TestFlight is enabled by default)
		-v change the version and use a new provisioning profile

		If you run into issues, please take screenshots of your terminal window and share with DoubleDutch.'
	shift 1
    ;;
	t)
    testFlightOpt=true
		info "TestFlight option enabled."
		shift 1
    ;;
	v)
		versionCustomFlag=true
		info "Version customization option enabled."
		shift 1
    ;;
	\?)
  	echo "Invalid option: -$OPTARG" >&2
    ;;
esac
done

datevar=$(date +%m_%d_%H_%M)
tmpDir=$(mktemp -dt codesigndd)
currentDir=$(pwd)

# determine file type and assign to correct value
for var do
	if [[ -e "$var" ]]; then
		if [[ -e ./"$var" ]]; then 
		var=("$currentDir/$var")
		fi
		mimeType=$(file --mime-type "$var" | cut -d ":" -f2)
		if [[ "$mimeType" == " application/zip" ]]; then
			zipCheck=$(unzip -l "$var" | grep Payload/Flock.app | wc -l )
			if [[ ! $zipCheck == 0 ]]; then
					app="$var"
			else
				error "$var" is not the .ipa provided by DoubleDutch
			fi
		elif [[ "$mimeType" == " application/octet-stream" ]]; then
				profile="$var"
		else
			error "$var is an invalid argument as it is of file type:$mimeType."
		fi
	else
		error "$var is an invalid argument as it is of file type:$mimeType."
	fi
done

[[ -d $tmpDir ]] || (error "Could not create directory")

pushd $tmpDir &> /dev/null

if [[ $# -lt 2 ]]; then
	error 'Usage: This script requires 2 arguments, that can be passed in any order.
	The path to the .ipa file DoubleDutch sent.
	The path to the provisioning profile you created for this app.'
fi

if [[ ! -f /usr/libexec/PlistBuddy ]]; then
  error "This script requires Xcode Command Line Tools, which are not present on your system. 
	For more information see https://developer.apple.com/library/ios/technotes/tn2339/_index.html 
	You can also try typing this on command line: Xcode-select --install"
fi

# this block setups the initial filepath for the codesigning to happen
cp "$app" app.zip
cp "$profile" temp.mobileprovision
info "Unzipping IPA, this might take a moment."
unzip app.zip >&-
if ! [[ -e Payload/Flock.app/info.plist ]]; then
	error "There is an issue with the IPA. Please contact DoubleDutch for a new file."
fi

if [[ ! $enterpriseOpt ]] && [[ ! -e SwiftSupport ]]; then
	error "SwiftSupport folder is missing. Please contact DoubleDutch for a new file."
fi

# this block extracts data from the provisioning profile and assigns that data to variables
security cms -D -i temp.mobileprovision > temp.plist 2> /dev/null
profileCheck=$(grep -c "data" temp.plist)
if [[ profileCheck -lt 1 ]]; then
	error "There is an issue with the provided provisioning profile. 
	Please try again with a freshly downloaded provisioning profile."
fi
expiryDate=$(/usr/libexec/PlistBuddy -c "Print ExpirationDate" temp.plist | cut -d " " -f 1-3,6 -) 2> /dev/null
expiryFormatted=$(date -jf"%a %b %d %Y" "$expiryDate" +%Y%m%d) 2> /dev/null
todayFormatted=$(date +%Y%m%d) 2> /dev/null
if [[ "$expiryFormatted" -lt "$todayFormatted" ]];
	then
	expiryINTLFormatted=$(date -jf"%a %d %b %Y" "$expiryDate" +%Y%m%d) 2> /dev/null
	if [[ "$expiryINTLFormatted" -lt "$todayFormatted" ]];
		then
		error "Provisioning profile has expired.
		Go to developer.apple.com and update Provisioning profile with an up to date Distribution certificate."
	fi
fi

pushCheck=$(/usr/libexec/PlistBuddy -c "Print Entitlements:aps-environment" temp.plist)
asdCheck=$(grep -c "com.apple.developer.associated-domains" temp.plist)
appIdLong=$(/usr/libexec/PlistBuddy -c "Print Entitlements:application-identifier" temp.plist)
appIdPrefix=$(echo $appIdLong | cut -d "." -f 1)
reverseUrl=$(echo $appIdLong | cut -d "." -f2- )
finalName=$(echo $reverseUrl | tr "." "_")
teamNameProvisioningProfile=$(/usr/libexec/PlistBuddy -c "Print TeamName" temp.plist)
teamIdProvisioningProfile=$(/usr/libexec/PlistBuddy -c "Print TeamIdentifier:0" temp.plist)

if [[ ! $teamIdProvisioningProfile ==  $appIdPrefix ]]; then
	info "Team ID and App ID Prefix do not match. This is allowed but not advised. No action needed at this time."
fi

info "Creating entitlements.plist based on existing app"
/usr/bin/codesign -d --entitlements :entitlements.plist Payload/Flock.app &> /dev/null
if [[ ! -e entitlements.plist ]]; then
	error "Entitlements.plist not created. Run script again."
fi
/usr/libexec/PlistBuddy -c "Set com.apple.developer.team-identifier $teamIdProvisioningProfile" entitlements.plist
/usr/libexec/PlistBuddy -c "Set application-identifier $appIdLong" entitlements.plist
/usr/libexec/PlistBuddy -c "Set keychain-access-groups:0 $appIdLong" entitlements.plist


if [[ $testFlightOpt ]]; then
	prompt "Would you like to disable TestFlight? If so type 'y' otherwise type 'n' or press Enter"
	read choice
	if [[ $choice == 'y' ]]; then
		/usr/libexec/PlistBuddy -c "Delete beta-reports-active" entitlements.plist
	fi
fi

if [[ $asdCheck == "0" ]]
	then
		error "This provisioning profile does not have Associated Domains entitlement! 
		This entitlement is required by this app and can be enabled from developer.apple.com.
		It will require a new provisoining profile after the App ID is updated to include Associated Domains."
fi

if [[ "$pushCheck" = "production" ]];
	then
		info "Push is enabled for use in production on this provisioning profile."
	elif [[ "$pushCheck" = "development" ]];
		then
			info "Push is enabled for use in development on this provisioning profile."
			info "This provisioning profile cannot be used for upload to App Store."
			/usr/libexec/PlistBuddy -c "Set aps-environment development" entitlements.plist
	else
		error "This provisioning profile doesn't have push entitlement!"
fi

# move the provisioning profile into the app
cp temp.mobileprovision Payload/Flock.app/embedded.mobileprovision

# This block edits the info.plist
/usr/libexec/PlistBuddy -c "Set CFBundleIdentifier $reverseUrl" Payload/Flock.app/info.plist
/usr/libexec/PlistBuddy -c "Set CFBundleURLTypes:0:CFBundleURLName $reverseUrl.custom" Payload/Flock.app/info.plist
/usr/libexec/PlistBuddy -c "Set CFBundleURLTypes:0:CFBundleURLSchemes:0 $reverseUrl.bundle" Payload/Flock.app/info.plist
/usr/libexec/PlistBuddy -c "Set CFBundleURLTypes:1:CFBundleURLName $reverseUrl.bundle" Payload/Flock.app/info.plist
/usr/libexec/PlistBuddy -c "Set CFBundleURLTypes:2:CFBundleURLName $reverseUrl.context_id" Payload/Flock.app/info.plist

if [[ $versionCustomFlag ]]; then
	shortVersion=$(/usr/libexec//PlistBuddy -c "Print CFBundleShortVersionString" Payload/Flock.app/info.plist)
	longerVersion=$(/usr/libexec//PlistBuddy -c "Print CFBundleVersion" Payload/Flock.app/info.plist)

	info "current Short version is $shortVersion"
	prompt "Do you want to change the short version string? 
	If so, type the version as x.x.x when done hit Enter. 
	To keep the existing shortVersion type 'n' then hit Enter"
	read newShort

	if ! [[ $newShort == "n" ]]; then
		/usr/libexec//PlistBuddy -c "Set CFBundleShortVersionString $newShort" Payload/Flock.app/info.plist
	fi

info "current longer version is $longerVersion"
prompt "Do you want to change the long version string? 
If so, type the version as x.x.x.x when done hit Enter.
To keep the existing long version string type 'n' then hit Enter"
read newLong
	if ! [[ $newLong == "n" ]]; then
		/usr/libexec//PlistBuddy -c "Set CFBundleVersion $newLong" Payload/Flock.app/info.plist
	fi
fi
# This is the actual codesigning
# determines the sha-1 value of the distribution certificate that is embedded in the provided provisioning profile $profile
certHash=$(cat temp.plist \
	| sed -ne 's/^.*<data>\(.*\)<\/data>.*$/\1/p' \
	| base64 -D \
	| shasum \
	| cut -d  " " -f1 \
	| tr '[:lower:]' '[:upper:]')
/usr/bin/security find-identity -v -p codesigning > identity.txt
countOfSigningIdentities=$(cat identity.txt \
	| grep "valid identities found" \
	| cut -d "v" -f1 \
	| tr -d [:blank:])
if [[ ! $countOfSigningIdentities == 0 ]]; then
	info "You have $countOfSigningIdentities valid signing identities in your Keychain."
else
	error "You have 0 valid signing identities.
	A valid Distribution certificate is needed to continue."
fi

certHashCount=$(grep "$certHash" identity.txt | wc -l | tr -d [:blank:]) 

if ! [[ "$certHashCount" == "0" ]]; then
		info "Distribution Certificate present for $teamNameProvisioningProfile"
		info "Codesigning the App"
		if [[ $enterpriseOpt == true ]]; then
			info "Signing app for Enterprise Distribution"
			codesign -fs "$certHash" Payload/Flock.app/Frameworks/*.dylib
		fi
		if [[ -e Payload/Flock.app/Frameworks/Sentry.framework ]]; then
			codesign -fs "$certHash" Payload/Flock.app/Frameworks/Sentry.framework >/dev/null
		else
			error "Sentry Framework is missing."
		fi
		codesign -fs "$certHash" --entitlements entitlements.plist Payload/Flock.app >/dev/null
elif [[ "$certHashCount" == "0" ]]; then
	error "The correct distribution certificate is not present in Keychain Access. 
	Match the expiry date of the Distribution Certificate with that from the provisioning profile, which is $expirydate"
fi

#info "This is the contents of entitlements file that was used:"
#codesign -d --entitlements :- Payload/Flock.app

# validation
printf "Validating the signing [    ]\r"
codesign -dvvv Payload/Flock.app &> validation.txt 
validationReverseURL=$(grep "Identifier" validation.txt | cut -d "=" -f2 | tr "\n" " " | cut -d " " -f1)
validationTeamDigit=$(grep "TeamIdentifier" validation.txt | cut -d "=" -f2)
validationSignedTime=$(grep "Signed Time" validation.txt | cut -d "=" -f2 | cut -d "," -f1-2)
validationSignedTimeFormatted=$(date -jf"%b %d, %Y" "$validationSignedTime" +%Y%m%d)
entitlementsSigningTeamDigit=$(/usr/libexec/PlistBuddy -c "Print com.apple.developer.team-identifier" entitlements.plist)

if [[ "$validationSignedTimeFormatted" -ne "$todayFormatted" ]];
	then
	validationSignedINTLTimeFormatted=$(date -jf"%d %b, %Y" "$validationSignedTime" +%Y%m%d)
	if [[ "$validationSignedINTLTimeFormatted" -ne "$todayFormatted" ]];
		then
		error "Time of codesigning not correct. Codesigning was not successful."
	fi
fi
printf " Validating the signing [-   ]\r"
sleep 1
if [[ "$reverseUrl" != "$validationReverseURL" ]];
	then
	error "Reverse URL was not updated successfully. Codesigning was not successful."
fi
printf " Validating the signing [--  ]\r"
sleep 1
if [[ "$validationTeamDigit" != "$teamIdProvisioningProfile" ]];
	then
	error "Team Identifier is incorrect. Codesigning was not successful."
fi
printf " Validating the signing [--- ]\r"
sleep 1
if [[ "$entitlementsSigningTeamDigit" != "$teamIdProvisioningProfile" ]];
	then
	error "Team Identifier is incorrect. Codesigning was not successful."
fi
printf " Validating the signing [----]\n"
info "App Signing Validated"
info "Zipping IPA, this might take a moment."
mkdir ~/desktop/Codesign_Output-$datevar
mv entitlements.plist ~/Desktop/Codesign_Output-$datevar/entitlements.plist
if [[ $enterpriseOpt == true ]]; then
		info "Exporting app for Enterprise Distribution"
		zip -rq  ~/Desktop/Codesign_Output-$datevar/"$finalName"-public-store.ipa Payload/
	else
		info "Exporting app for App Store Distribution"
		zip -rq  ~/Desktop/Codesign_Output-$datevar/"$finalName"-public-store.ipa Payload/ SwiftSupport/
fi
info "The finished file is on your Desktop in a folder called Codesign_Output-$datevar"
open ~/Desktop/Codesign_Output-$datevar
