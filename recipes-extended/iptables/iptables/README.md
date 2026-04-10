# Firewall Rules

Default-deny firewall rulesets for IPv4 (`iptables.rules`) and IPv6 (`ip6tables.rules`).

## Policy

All chains (INPUT, FORWARD, OUTPUT) default to **DROP**. Only explicitly allowed traffic passes.

## Allowed Traffic

### Inbound (INPUT)

| Protocol | Port | Source | Rate Limit | Purpose |
|----------|------|--------|------------|---------|
| TCP | 22 (SSH) | any | 3/min, burst 5 | Remote management |
| TCP | 443 (HTTPS) | private subnets only | 25/min, burst 50, max 30 concurrent | Application service |
| TCP | 5252 | private subnets only | 10/min, burst 20, max 30 concurrent | Tailscale web management |
| any | any | tailscale0 interface | none | Tailscale tunnel traffic |
| ICMP echo-request |  NA | any | 1/sec | Ping |
| UDP | 68 (DHCPv4) / 546 (DHCPv6) | DHCP server |  NA | Address assignment |

### Outbound (OUTPUT)

| Protocol | Port | Purpose |
|----------|------|---------|
| TCP | 443 | HTTPS |
| UDP | 123 | NTP time sync |
| UDP+TCP | 53 | DNS resolution |
| UDP | 67 (DHCPv4) / 547 (DHCPv6) | DHCP client requests |
| any | any | tailscale0 tunnel traffic |
| UDP | 41641 | WireGuard direct connections |
| ICMP echo-request |  NA | Ping |

### IPv4-specific

- HTTPS inbound restricted to RFC 1918 subnets: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`

### IPv6-specific

- HTTPS inbound restricted to ULA (`fc00::/7`) and link-local (`fe80::/10`)
- NDP (Neighbor Discovery Protocol) is allowed with hop-limit = 255 to prevent off-link spoofing:
  - **Input**: Router Advertisement (134), Neighbor Solicitation (135), Neighbor Advertisement (136)
  - **Output**: Router Solicitation (133), Neighbor Solicitation (135), Neighbor Advertisement (136)

## Common rules

- Loopback (`lo`) traffic is always allowed
- INVALID conntrack packets are dropped early
- ESTABLISHED/RELATED connections are allowed (stateful tracking)
- FORWARD is fully dropped (no routing/NAT)
