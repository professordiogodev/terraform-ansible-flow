# Lab 1 (Easy): The maintenance page

**Branch:** `main` · **Time:** ~30 min

## 📩 The request

> **From:** Sam (Team Lead)
> **Subject:** Server for the maintenance page
>
> Hi! Tonight we're doing maintenance on the main website, and we need a server that shows a "we'll be back soon" page.
>
> 1. One server in `us-east-1` with **Nginx** and **git** installed
> 2. The web page must say **"Maintenance in progress - back soon!"**
> 3. When someone logs in with SSH, they should see the message **"Maintenance server - do not use for anything else"**
>
> Send me proof that it works. Thanks!

## Part 1: Create the infrastructure

Follow steps 1 and 2 of the [README](README.md):

```bash
cd infra
terraform init
terraform apply -var student_name=yourname
cd ../ansible
ansible all -m ping
```

✅ You should get `"ping": "pong"`.

## Part 2: Create the web page

Create a folder `ansible/files/` and, inside it, a file `index.html`:

```html
<h1>Maintenance in progress - back soon!</h1>
```

## Part 3: Write the playbook

Create **`ansible/lab.yml`**. Start by copying the first lines of `playbook.yml` (the `name`, `hosts` and `become` lines), then add these tasks:

| # | Task | Module to use |
|---|---|---|
| 1 | Install `nginx` and `git` | `ansible.builtin.dnf` |
| 2 | Copy `files/index.html` to `/usr/share/nginx/html/index.html` | `ansible.builtin.copy` (with `src`) |
| 3 | Create the file `/etc/motd` with the text `Maintenance server - do not use for anything else` | `ansible.builtin.copy` (with `content`) |
| 4 | Start Nginx and enable it at boot | `ansible.builtin.systemd` |

> [!NOTE]
> `/etc/motd` means "message of the day". Linux shows its content every time someone logs in with SSH.

Run it:

```bash
ansible-playbook lab.yml
```

## Part 4: Test it

| # | Check | Command | Expected result |
|---|---|---|---|
| 1 | The page is online | `curl http://$(terraform -chdir=../infra output -raw public_ip)` | `Maintenance in progress - back soon!` |
| 2 | Nginx is running | `ansible all -a "systemctl is-active nginx"` | `active` |
| 3 | Git is installed | `ansible all -a "git --version"` | A version number |
| 4 | The login message works | `ssh -i yourname-ssh-key.pem ec2-user@<public_ip>` | The message is shown when you log in (type `exit` to leave) |

> [!TIP]
> Run `ansible-playbook lab.yml` a second time. The tasks now say `ok` instead of `changed`: Ansible only changes what isn't already the way you asked.

## Part 5: Clean up

> [!CAUTION]
> Always destroy your infrastructure when you're done. Servers cost money while they run.

```bash
cd ../infra
terraform destroy -var student_name=yourname
```

## Deliverables

- Your `ansible/lab.yml` and `ansible/files/index.html`
- The output of the 4 checks above

<details>
<summary>💡 Hints (only if you're stuck)</summary>

- Installing 2 packages at once:
  ```yaml
  ansible.builtin.dnf:
    name: [nginx, git]
    state: present
  ```
- Copying a file from your computer: `src: files/index.html` and `dest: /usr/share/nginx/html/index.html`.
- Writing a file from text: use `content:` instead of `src:`.
- Look at `playbook.yml`: it already has a task that starts Nginx.

</details>
