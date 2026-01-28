# Tutorial: Secure AWS VPC Access with NetBird

This tutorial guides you through configuring NetBird to provide secure remote access to resources within an AWS VPC. We will use a "Gateway Peer" to route traffic from the NetBird network to your private AWS subnet.

## Prerequisites

*   An active NetBird account.
*   An AWS VPC with at least one private subnet.
*   An EC2 instance in that VPC to serve as the NetBird Gateway.

## Step 1: AWS VPC Configuration

### 1.1. Security Group Setup

You need to allow traffic from the NetBird Gateway peer to the private resources you want to access.

1.  Identify the Security Group assigned to your private resources (e.g., `web-sg` or `internal-db-sg`).
2.  Add an **Inbound Rule** to allow all traffic (or specific ports) from the **Private IP of the NetBird Gateway EC2 instance**.

![Placeholder: AWS Console showing Security Group Inbound Rules configuration](file:///home/richemond/Projects/netbird/docs/img/aws-sg-config.png)

### 1.2. Routing Table Check

Ensure the private resources have a route to the NetBird Gateway if you need bidirectional communication, although for simple egress access from NetBird to VPC, the default local route is usually sufficient if the Gateway performs masquerading (which NetBird does by default).

## Step 2: NetBird Gateway Installation

1.  SSH into your Gateway EC2 instance.
2.  Install the NetBird client following the [standard installation guide](https://docs.netbird.io/how-to/getting-started#install-netbird).
3.  Up the client: `netbird up`.

## Step 3: Configure NetBird Routing Peer

1.  Log in to the [NetBird Dashboard](https://app.netbird.io/).
2.  Go to the **Network Routes** section.
3.  Click **Add Route**.
4.  **Network Range**: Enter the CIDR of your AWS VPC (e.g., `10.0.0.0/16`).
5.  **Routing Peer**: Select your Gateway EC2 instance from the dropdown.
6.  **Groups**: Select the groups that should have access to this route (e.g., `All`).
7.  Click **Save**.

![Placeholder: NetBird Dashboard showing Network Route configuration](file:///home/richemond/Projects/netbird/docs/img/netbird-route-config.png)

## Step 4: Fine-Grained Access Control

To restrict access, use NetBird Groups and Access Policies.

1.  **Create Groups**: Go to **Groups** and create one for your AWS Resources (e.g., `aws-production`) and one for your Users (e.g., `developers`).
2.  **Assign Peers**: Add your Gateway peer to the `aws-production` group.
3.  **Create Policy**: Go to **Access Control** and create a policy that allows `developers` to access `aws-production`.

![Placeholder: NetBird Dashboard showing Access Control Policy configuration](file:///home/richemond/Projects/netbird/docs/img/netbird-policy-config.png)

## Step 5: Verification

1.  On your local machine, connect to NetBird: `netbird up`.
2.  Attempt to ping or SSH into a private IP within your AWS VPC.
    ```bash
    ping 10.0.1.50  # Replace with a private IP in your VPC
    ```

---

> [!IMPORTANT]
> Ensure that the EC2 Gateway instance has "Source/Destination Check" disabled in the AWS Console if you encounter routing issues. This is found under **Actions > Networking > Change Source/Destination Check**.
