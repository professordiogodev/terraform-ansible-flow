# Lab 3 (Hard): Which server answered?

**Branch:** `load-balancer` · **Time:** ~1 hour

## 📩 The request

> **From:** Sam (Team Lead)
> **Subject:** Website behind the load balancer
>
> Hi! Our website runs on 3 servers behind a load balancer. Before we go live, I need a few changes:
>
> 1. Every page must show **which server** answered and the **website version** (`1.0`)
> 2. Add a page at **`/health.html`** that just says **`OK`**, for our monitoring tool
> 3. Prove that **if one server goes down, the website keeps working**
>
> Thanks!

## Part 1: Create the infrastructure

Follow the [README](README.md) up to step 3: create the infrastructure, run `render-template.yaml`, and check the load balancer with `curl`.

To make the next commands shorter, save the ALB address in a variable (run this inside `ansible/`):

```bash
ALB=$(terraform -chdir=../infra output -raw alb_dns)
curl http://$ALB
```

> [!NOTE]
> `$ALB` only exists in the terminal where you created it. If you open a new terminal, run that line again.

## Part 2: Show the server name and version

The page comes from a **template**: `ansible/roles/nginx-html-templating/templates/index.html.j2`.
Ansible replaces everything inside `{{ }}` with the value of a variable. For example, `{{ username }}` becomes `Alberta` on server `a`, because of `host_vars/a.yml`.

1. Open `index.html.j2` and add these 2 lines under the `<h1>` line:
   ```html
   <p>Served by: {{ inventory_hostname }}</p>
   <p>Version: {{ site_version }}</p>
   ```
   `inventory_hostname` is filled in by Ansible automatically. It's the server's name in `inventory.ini` (`a`, `b` or `c`).

2. `site_version` doesn't exist yet. Create it in the role's default variables, `ansible/roles/nginx-html-templating/defaults/main.yml`:
   ```yaml
   site_version: "1.0"
   ```

> [!TIP]
> Variables in `defaults/main.yml` apply to every server that uses the role. That's why we put the version there and not in `host_vars`.

## Part 3: Add the health page

1. Create the folder `ansible/roles/nginx-html-templating/files/` and, inside it, a file called `health.html` that contains only `OK`.
2. At the end of `ansible/roles/nginx-html-templating/tasks/main.yml`, add a task that copies it to `/usr/share/nginx/html/health.html` with `ansible.builtin.copy`.

> [!TIP]
> Inside a role, `src: health.html` automatically looks in the role's `files/` folder. You don't need to write the full path.

Run the playbook again:

```bash
ansible-playbook render-template.yaml
```

## Part 4: Test it

| # | Check | Command | Expected result |
|---|---|---|---|
| 1 | Each request goes to a server | `for i in 1 2 3 4 5 6; do curl -s http://$ALB \| grep "Served by"; done` | A mix of `a`, `b` and `c` |
| 2 | The version is shown | `curl -s http://$ALB \| grep Version` | `Version: 1.0` |
| 3 | The health page works | `curl http://$ALB/health.html` | `OK` |

## Part 5: Take a server down 💥

Let's simulate a crash on server `b` by stopping Nginx on it:

```bash
ansible b -b -a "systemctl stop nginx"
```

Now look at the HTTP status codes the ALB returns:

```bash
for i in 1 2 3 4 5 6; do curl -s -o /dev/null -w "%{http_code}\n" http://$ALB; done
```

> [!WARNING]
> For about **1 minute**, some requests fail with **`502`** (Bad Gateway). The ALB is still sending traffic to `b`, but `b` doesn't answer.

The ALB checks every server every 30 seconds. After 2 failed checks, it marks `b` as **unhealthy** and stops sending it traffic.
Run check 1 again: only `a` and `c` answer now, and no more `502`s. **The website keeps working with 2 servers.** ✅

Now bring `b` back. You don't need to fix it by hand: just run the playbook again. Ansible sees that Nginx should be `started` and starts it.

```bash
ansible-playbook render-template.yaml
```

> [!NOTE]
> The ALB needs **5 good checks in a row** (about 2–3 minutes) before it trusts `b` again. Wait, then run check 1 again and `b` comes back.

## Part 6: Clean up

> [!CAUTION]
> Don't forget this step. The load balancer costs money every hour it runs.

```bash
cd ../infra
terraform destroy -var student_name=yourname
```

## Deliverables

- Your changes to the role: `templates/index.html.j2`, `defaults/main.yml`, `files/health.html` and `tasks/main.yml`
- The output of the 3 checks in Part 4
- The output of Part 5: the `502`s, then only `a` and `c`, then `b` back again

## ⭐ Bonus

Sam wants version `2.0` live. Change `site_version`, run the playbook again and check that all 3 servers show `Version: 2.0`.

<details>
<summary>💡 Hints (only if you're stuck)</summary>

- The copy task looks like this:
  ```yaml
  - name: Copy the health page
    ansible.builtin.copy:
      src: health.html
      dest: /usr/share/nginx/html/health.html
      mode: '0644'
  ```
- Error `'site_version' is undefined`? Check that you added it to `defaults/main.yml` (in the role folder, not somewhere else).
- `curl` shows a page with no "Served by" line? You probably edited the template but didn't run the playbook again.

</details>
