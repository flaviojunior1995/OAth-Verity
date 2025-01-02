# Install
## Create the script folder
```
# mkdir /etc/freeradius/3.0/scripts
```
## Upload the script to script folder
```
# mv oathverify.sh /etc/freeradius/3.0/scripts
```
## Upload the module oath to module-available folder
```
# mv oath /etc/freeradius/3.0/module-available
```
## Enable module
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

The authenticate will check the password as PIN + OTP
Example:
PIN = 1234
OTP = 332 773
Password = 1234332773
```
# nano /etc/freeradius/3.0/users
"
user2 Auth-Type = OATH
	OATH-Init-Secret = "base32 secret"
	OATH-PIN = "user PIN"
	OATH-Offset = 0
"
```
