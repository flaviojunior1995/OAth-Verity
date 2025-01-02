# OAth Verify
## Description
OAth Verify is a script done for freeradius to authenticate users using OTP, the script checks the password as PIN + OTP to Accept the request, the script also block the users if it fails 10 times

# How to use
## Create the script folder
```
# mkdir /etc/freeradius/3.0/scripts
```
## Move the oathverify.sh to script folder
```
# mv oathverify.sh /etc/freeradius/3.0/scripts
```
## Move the module oath to module-available folder
```
# mv oath /etc/freeradius/3.0/module-available
```
## Enable module on freeradius
```
# ln /etc/freeradius/3.0/module-available/oath /etc/freeradius/3.0/module-enable/
```

## Edit site default to use Auty-Type oath on authenticate
```
# nano /etc/freeradius/3.0/sites-enabled/default
"
...
authenticate {
	Auth-Type OATH {
		oath
	}
...
"
```
## Create users
To create user there are 3 parameters to enable the OTP

 1. OATH-Init-Secret = "init-secred from token Base32"
 2. OATH-PIN = "user PIN"
 3. OATH-Offset = "time difference between token and server in 10s of seconds (360 = 1 hour)"
```
# nano /etc/freeradius/3.0/users
"
user2 Auth-Type = OATH
	OATH-Init-Secret = "base32 secret"
	OATH-PIN = "user PIN"
	OATH-Offset = 0
"
```
