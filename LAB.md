# Lab 2 (Medium): Deploy the Noderino app

**Branch:** `three-instances` · **Time:** ~45 min

## 📩 The request

> **From:** Sam (Team Lead)
> **Subject:** Noderino needs to go live
>
> Hi! The dev team finished **Noderino**, a small Node.js app: https://github.com/professordiogodev/devops.noderino
>
> We want it running on **3 servers** so we have a backup if one goes down. Can you use our Terraform + Ansible repo to set it up?
>
> 1. Three servers in `us-east-1`
> 2. Noderino running on all 3, on port **3000**
> 3. In the app settings, set `NUMBER` to **42**
> 4. The app must keep running in the background, even after a reboot
>
> Send me proof it works on all 3 servers. Thanks!

## Part 1: Create the infrastructure (and open port 3000)

> [!IMPORTANT]
> By default, the servers only accept traffic on ports 22 (SSH) and 80 (HTTP). The app runs on port **3000**, so you need to open it first.

Add this rule at the end of **`infra/main.tf`**:

```hcl
# Allow traffic to the Noderino app
resource "aws_vpc_security_group_ingress_rule" "allow_app_port" {
  security_group_id = aws_security_group.allow_http_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 3000
  to_port           = 3000
  ip_protocol       = "tcp"
}
```

Then create the servers and check that Ansible can reach them:

```bash
cd infra
terraform init
terraform apply -var student_name=yourname
cd ../ansible
ansible all -m ping
```

✅ You should get `"ping": "pong"` from `a`, `b` and `c`.

## Part 2: Prepare the service file

You might think: "why not just add a task that runs `node index.js`?" It won't work. 👇

> [!WARNING]
> **Don't start the app directly from Ansible** (for example with `ansible.builtin.command: node index.js`).
> Ansible runs every task through an SSH connection. Anything started by a task is a **child** of that connection.
> When the task ends, Ansible closes the connection, and the server **kills the `node` process with it**.
> The playbook says "ok", but the app is gone a second later. (And if `node` did stay attached, the task would never end and the playbook would hang.)

The solution is **systemd**, the Linux service manager. A process started by systemd belongs to systemd, not to your SSH connection.
So it keeps running after Ansible disconnects, restarts if it crashes, and starts again after a reboot.

systemd needs a small "service file" that says how to start the app.

Create **`ansible/files/noderino.service`** with this content (you don't need to change it):

```ini
[Unit]
Description=Noderino app
After=network.target

[Service]
WorkingDirectory=/opt/noderino
ExecStart=/usr/bin/node index.js
Restart=always
User=ec2-user

[Install]
WantedBy=multi-user.target
```

## Part 3: Write the playbook

Create **`ansible/app.yml`**. It should run on the `web` hosts with `become: true` (like `playbook.yml`), and do these tasks **in this order**:

| # | Task | Module to use |
|---|---|---|
| 1 | Install `nodejs`, `npm` and `git` | `ansible.builtin.dnf` |
| 2 | Download the app code from `https://github.com/professordiogodev/devops.noderino.git` into `/opt/noderino` | `ansible.builtin.git` |
| 3 | Install the app's dependencies by running `npm install` inside `/opt/noderino` | `ansible.builtin.command` (with `chdir`) |
| 4 | Create the file `/opt/noderino/.env` with `PORT=3000` and `NUMBER=42` (one per line) | `ansible.builtin.copy` (with `content`) |
| 5 | Copy `files/noderino.service` to `/etc/systemd/system/noderino.service` | `ansible.builtin.copy` (with `src`) |
| 6 | Start the `noderino` service and enable it at boot | `ansible.builtin.systemd` |

Run it:

```bash
ansible-playbook app.yml
```

## Part 4: Test it

Get the IPs with `terraform -chdir=../infra output public_ip`, then run each check and save the output. That's your proof for Sam.

| # | Check | Command | Expected result |
|---|---|---|---|
| 1 | Node.js is installed | `ansible all -a "node --version"` | A version number on all 3 servers |
| 2 | The app is running | `ansible all -a "systemctl is-active noderino"` | `active` on all 3 servers |
| 3 | The app answers | `curl http://<ip>:3000` (for each of the 3 IPs) | `Hello from / number 42!` |
| 4 | The health check works | `curl http://<ip>:3000/healthcheck` | `It works!` |
| 5 | It survives a reboot | `ansible a -b -m reboot`, then check 3 again on server `a` | Still `Hello from / number 42!` |

## Part 5: Clean up

> [!CAUTION]
> Always destroy your infrastructure when you're done. Servers cost money while they run.

```bash
cd ../infra
terraform destroy -var student_name=yourname
```

## Deliverables

- Your `ansible/app.yml` and `ansible/files/noderino.service`
- The output of the 5 checks above

<details>
<summary>💡 Hints (only if you're stuck)</summary>

- Installing several packages at once:
  ```yaml
  ansible.builtin.dnf:
    name: [nodejs, npm, git]
    state: present
  ```
- Cloning a repo:
  ```yaml
  ansible.builtin.git:
    repo: https://github.com/professordiogodev/devops.noderino.git
    dest: /opt/noderino
  ```
- Running a command inside a folder:
  ```yaml
  ansible.builtin.command: npm install
  args:
    chdir: /opt/noderino
  ```
- Writing a file with several lines: use `content: |` and put each line below it, indented.
- Starting a service you just added: in `ansible.builtin.systemd` use `state: started`, `enabled: true` and `daemon_reload: true`
  (this makes systemd read the new service file).
- The playbook worked but `curl` says "connection refused"? The app isn't running: check `ansible all -a "systemctl status noderino"`.
- `curl` hangs on port 3000? Check that you added the security group rule in Part 1 and ran `terraform apply` again.

</details>
