+++
    title = "Hack The Box: Delivery"
    date = "2021-05-01T20:27:09+10:00"
    author = "Jarrod Cameron"
    authorTwitter = "" #do not include @
    cover = "/posts/delivery/banner.png"
    tags = ["HackTheBox", "writeup"]
    keywords = ["first", "second"]
    description = "This machine starts with requesting a ticket from a service which returns an email. This email can be then used to signup for a seperate service. This new service contains chat logs with some credentials in plaintext. These credentials can be used to SSH into the machine. Some searching around leads to the credentials of the back end database, which contains a hash of the password used by the root user. After extracting and cracking this hash, `su` can be used access the root account."
    showFullContent = false
    draft = false
+++

# Enumeration

It's difficult to attack a machine without knowing what's available, so firstly
I run `nmap` so see all of the open TCP ports.

```bash
# Run as root
nmap -sS -p- '10.10.10.222'
```

| Argument | What/Why |
|----------|----------|
| `-sS`    | This peforms a TCP SYN scan, or in other words `nmap` will send the first packet of a TCP handshake but not complete the handshake. This cuts down on the amount of work required by `nmap` (since only part of the connection needs to be completed). Since this option requires `nmap` to modify raw TCP packets, root privleges are needed. |
| `-p-`    | This option forces `nmap` to scan all 65535 ports. |
| `10.10.10.222` | This is the IPv4 address of the target machine (supplied by the challenge). |

When `nmap` eventually finishes I get the following output:

```text
Starting Nmap 7.91 ( https://nmap.org ) at 2021-05-06 08:48 AEST
Nmap scan report for 10.10.10.222
Host is up (0.015s latency).
Not shown: 65532 closed ports
PORT     STATE SERVICE
22/tcp   open  ssh
80/tcp   open  http
8065/tcp open  unknown

Nmap done: 1 IP address (1 host up) scanned in 12.42 seconds
```

## Enumerating: Port 80/TCP (http)

Port 80, using the TCP protcol, is most commonly viewed in a browser. When
visiting the url [http://10.10.10.222/](http://10.10.10.222/), I'm met with the
following page:

{{< image src="80root.png" position="center" style="border-radius: 8px;" >}}

After clicking on the "CONTACT US" button, I was redirected to the following
page:

{{< image src="80contact.png" position="center" style="border-radius: 8px;" >}}

The are two links on this page:

- `HelpDesk` sends the browser to [http://helpdesk.delivery.htb/](http://helpdesk.delivery.htb/).
- `MatterMost server` sends the browser to [http://delivery.htb:8065/](http://delivery.htb:8065/).

Both of these URLs require the domain names "helpdesk.delivery.htb" and
"delivery.htb" to resolve to an IP address. I then modify the `/etc/hosts` file
to force these domains to resolve to "10.10.10.222" (the IPv4 of the target
machine). This can be done using the following command:

```bash
# Run as root
echo '10.10.10.222 delivery.htb helpdesk.delivery.htb' >> /etc/hosts
```

# Getting a `@delivery.htb` Email

When visiting [http://helpdesk.delivery.htb/](http://helpdesk.delivery.htb/)
I'm presented with the following page:

{{< image src="helpdesk_root.png" position="center" style="border-radius: 8px;" >}}

After filling out all the details...

{{< image src="helpdesk_open.png" position="center" style="border-radius: 8px;" >}}

I'm presented with the following screen:

{{< image src="helpdesk_email.png" position="center" style="border-radius: 8px;" >}}

From the above image I am allowed to use "4517601@delivery.htb" to
update the ticket. Or in other words, I have obtained an email with the
"delivery.htb" domain.

# Accessing `Mattermost`

When visiting [http://delivery.htb:8065/](http://delivery.htb:8065/) I'm
presented with a login screen but I don't know any valid credentials:

{{< image src="mattermost_root.png" position="center" style="border-radius: 8px;" >}}

After clicking on "Create one now." I'm prompted to fill our the forum with my
account information. I use the email with the "delivery.htb" domain for my
email.

{{< image src="mattermost_create.png" position="center" style="border-radius: 8px;" >}}

After selecting "Create Account" I'm visited with a message to verify my email.

## Verifying Account

I can navigate to
[http://helpdesk.delivery.htb/view.php](http://helpdesk.delivery.htb/view.php)
to check the email. After entering the appropriate information...

{{< image src="check_status.png" position="center" style="border-radius: 8px;" >}}

I'm given an email to verify my account!

{{< image src="verify.png" position="center" style="border-radius: 8px;" >}}

After using the link supplied I'm prompted to log in with the credentials I set
earlier.

## Navigating `Mattermost`

Once I'm inside, I navigate to various pages until I find an interesting page:

{{< image src="interesting.png" position="center" style="border-radius: 8px;" >}}

Some things from the above image:

- The username ("maildeliverer") and password ("Youve_G0t_Mail!") can be used
  to access OSTicket.
- Some passwords will be varaitions of "PleaseSubscribe!"
  - "hashcat rules" could crack hashes of these passwords.

# SSH'ing into delivery.htb

From the leaked credentials I try to SSH into the machine:

<!-- TODO modify image to show `Youve_G0t_Mail!` (pword) -->

{{< image src="ssh.png" position="center" style="border-radius: 8px;" >}}

## Accessing the Database

It's highly likely that Mattermost requires a database to store the
information and it must have some credentials stored in a configuration
file to access the database. While looking around the file system, I found the
file used store the credentials; `/opt/mattermost/config/config.json`.

{{< image src="sqlcreds.png" position="center" style="border-radius: 8px;" >}}

From the "DataSource" entry, I can see some credentials:

- Username: "mmuser"
- Password: "Crack_The_MM_Admin_PW"

## Extracting Hash from Database

After using the following command, I can then query the database for any
information I want.

```bash
mysql -u 'mmuser' -p'Crack_The_MM_Admin_PW' mattermost
```

Using the following command I can extract the hash of the user named "Root"
(which is the most interesting of the users).

```sql
SELECT Password FROM Users WHERE Username = 'Root';
```

This returns the following hash:

`$2a$10$VM6EeymRxJ29r8Wjkr8Dtev0O.1STWb4.4ScG.anuu7v0EFJwgjjO`

## Cracking the Hash

Using the following commands, I find the origional password which is
"PleaseSubscribe!21".

```bash
# The single credential from the database
$ echo 'root:$2a$10$VM6EeymRxJ29r8Wjkr8Dtev0O.1STWb4.4ScG.anuu7v0EFJwgjjO' > creds.txt

# The password from the Mattermost server
$ echo 'PleaseSubscribe!' > pass.txt

# Apply "hashcat" rules and crack password
$ john --wordlist=pass.txt --rules=hashcat creds.txt
[snip]
PleaseSubscribe!21 (root)
[snip]
```

# Privilege Escalation

Using the cracked password, "PleaseSubscribe!21", I can use `su` to switch user
to root!

{{< image src="privesc.png" position="center" style="border-radius: 8px;" >}}
