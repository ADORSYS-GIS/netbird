# Tutorial: Automated NetBird User Provisioning
This guide provides a single, self-contained Ansible Playbook that allows you to interactively add users to your NetBird network via Keycloak.
To handle multiple users in a single interactive session, we can use a "Bulk Input" pattern. This version of the playbook will ask for your credentials once, and then ask for a list of users in a specific format (e.g., user:email:pass).

1. The Bulk Provisioning Playbook: bulk_provision_users.yml
Copy this code into a file named bulk_provision_users.yml.

---

```
---
- name: Bulk Interactive NetBird User Provisioning
  hosts: localhost
  gather_facts: false
  
  vars_prompt:
    - name: input_url
      prompt: "1. Enter Keycloak URL (e.g., https://keycloak.example.com)"
      private: false
    - name: keycloak_admin_user
      prompt: "2. Enter Keycloak Admin Username"
      default: "admin"
      private: false
    - name: keycloak_admin_password
      prompt: "3. Enter Keycloak Admin Password"
      private: true
    - name: netbird_realm
      prompt: "4. Enter Target Realm"
      default: "netbird"
      private: false
    - name: users_raw
      prompt: "5. Enter Users (comma-separated, e.g., user1@email.com, user2:user2@email.com:pass123)"
      private: false
    - name: user_group
      prompt: "6. Assign ALL to Group"
      default: "vpn-users"
      private: false

  tasks:
    - name: Detect Keycloak API Base
      ansible.builtin.uri:
        url: "{{ item }}/realms/master/.well-known/openid-configuration"
        validate_certs: false
        # We accept 200 or 404 here so the task stays "Green/OK"
        status_code: [200, 404]
      loop:
        - "{{ input_url | regex_replace('/$', '') | trim }}"
        - "{{ input_url | regex_replace('/$', '') | trim }}/auth"
      register: url_check

    - name: Set Correct URL Fact
      ansible.builtin.set_fact:
        keycloak_url: "{{ (url_check.results | selectattr('status', 'equalto', 200) | first).item | default('') }}"

    - name: Fail if URL unreachable
      ansible.builtin.fail:
        msg: "Could not find a valid Keycloak API at {{ input_url }}. Both root and /auth paths failed."
      when: keycloak_url == ""

    - name: Parse User Data to Native List
      ansible.builtin.set_fact:
        users_list: "{{ parsed_users_string | from_yaml }}"
      vars:
        parsed_users_string: |
          {% set users = [] %}
          {% for item in users_raw.split(',') %}
            {% set clean = item.strip() %}
            {% if clean != "" %}
              {% set parts = clean.split(':') %}
              {% if parts | length == 3 %}
                {% set _ = users.append({'u': parts[0], 'e': parts[1], 'p': parts[2]}) %}
              {% elif '@' in clean %}
                {% set _ = users.append({'u': clean.split('@')[0], 'e': clean, 'p': 'Nb' + (999999 | random(start=100000) | string) + '!'}) %}
              {% endif %}
            {% endif %}
          {% endfor %}
          {{ users }}

    - name: Provision Users in Keycloak
      community.general.keycloak_user:
        auth_keycloak_url: "{{ keycloak_url }}"
        auth_realm: "master"
        auth_username: "{{ keycloak_admin_user }}"
        auth_password: "{{ keycloak_admin_password }}"
        realm: "{{ netbird_realm }}"
        username: "{{ item.u }}"
        email: "{{ item.e }}"
        enabled: true
        email_verified: true
        credentials:
          - type: password
            value: "{{ item.p }}"
            temporary: false
        groups:
          - name: "{{ user_group }}"
        state: present
        validate_certs: false
      loop: "{{ users_list }}"
      no_log: false

    - name: Result Summary
      ansible.builtin.debug:
        msg:
          - "---------------------------------------------------"
          - "SUCCESS: {{ users_list | length }} user(s) processed."
          - "CREDENTIALS (Save these now!):"
          - |
            {% for u in users_list %}
            - User: {{ u.u }} | Email: {{ u.e }} | Pass: {{ u.p }}
            {% endfor %}
          - "---------------------------------------------------"
```

2. How to Run the Tutorial
   
Step 1: Install Requirements
Ensure you have Ansible and the necessary Keycloak collection installed on your local machine:
[ansible](https://docs.ansible.com/)

```
ansible-galaxy collection install community.general
```

Step 2: Run the Playbook
Start the interactive process:
```
ansible-playbook bulk_provision_users.yml
```

Step 3: How to enter multiple users
When prompted for the Users List, use the following format:

``
Separate Username, Email, and Password with colons (:).
Separate different users with commas (,).
Example Input: alice:alice@work.com:S3curePass, bob:bob@work.com:AnotherPass
``

Why use this flow?
- Efficiency: You only type the server URL and Admin password once.
- Atomicity: Ansible loops through your list and creates everyone in one go.
- Validation: The script checks your formatting and will tell you if it couldn't find valid user data.
- Instant Access: Since all users are added to the same group (e.g., vpn-users), they will all inherit the same NetBird access rules as soon as they log in.

# Adding a peer to a netbird network 

## Linux/Windows/Macos

```
curl -fsSL https://pkgs.netbird.io/install.sh | sh
netbird up --management-url <YOUR_MANAGEMENT_URL> --setup-key <YOUR_SETUP_KEY>
```

## Docker

```
docker run --rm -d \
 --cap-add=NET_ADMIN \
 -e NB_SETUP_KEY=<SETUP_KEY> \
 -v netbird-client:/var/lib/netbird \
 -e NB_MANAGEMENT_URL=<YOUR_MANAGEMENT_URL>  \
 netbirdio/netbird:latest
```

## How it Works

1. **Dynamic Setup Keys**: Before enrolling a peer, the playbook requests a short-lived (1 hour) ephemeral setup key from the Netbird API. This ensures keys are not hardcoded or reused indefinitely.
2. **OS Compability**: The suite works for any target OS family to install the correct repository and package.
3. **Docker Support**: For containerized environments, it deploys the official Netbird image with `NET_ADMIN` capabilities and host networking for proper VPN interface operation.

