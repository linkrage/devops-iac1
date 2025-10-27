# SSL/TLS Certificate Setup for HTTPS

This project supports HTTPS via AWS Certificate Manager (ACM) certificates. You have **three options**:

---

## Option 1: No HTTPS (Default)

**Use Case:** Demo/testing without a domain

**Configuration:**
- No changes needed
- ALB will serve traffic over HTTP only

**URLs:**
- Access via: `http://<alb-dns-name>`

---

## Option 2: Bring Your Own Certificate (Manual)

**Use Case:** You already have an ACM certificate in AWS

### Steps:

1. **Get your certificate ARN** from AWS Console:
   - Go to: AWS Certificate Manager → Certificates
   - Copy the ARN (e.g., `arn:aws:acm:us-west-2:123456789:certificate/abc-123`)

2. **Configure Terragrunt:**

Edit `live/staging/terragrunt.hcl`:

```hcl
inputs = {
  enable_https         = true
  alb_certificate_arn  = "arn:aws:acm:us-west-2:123456789:certificate/your-cert-id"
  # ... other inputs
}
```

3. **Deploy:**

```bash
cd live/staging
terragrunt apply
```

4. **Create DNS Record:**

Point your domain to the ALB DNS name:
- **Type:** CNAME (or A record with Alias for apex domain)
- **Name:** Your domain (e.g., `app.example.com`)
- **Value:** ALB DNS name from output

**Result:**
- HTTP (port 80) → Redirects to HTTPS
- HTTPS (port 443) → Serves your application

---

## Option 3: Automatic Certificate Creation (Fully Automated)

**Use Case:** You have a domain in Route53 and want Terraform to handle everything

### Prerequisites:

1. **Domain registered** (anywhere: Route53, GoDaddy, Namecheap, etc.)
2. **Route53 Hosted Zone** for your domain
3. **NS records** at your registrar pointing to Route53

### Steps:

1. **Get your Route53 Zone ID:**

```bash
aws route53 list-hosted-zones --query 'HostedZones[*].[Name,Id]' --output table
```

Example output:
```
-------------------------------------------
|         ListHostedZones               |
+-----------------------+---------------+
|  example.com.         |  Z1234567890  |
+-----------------------+---------------+
```

2. **Configure Terragrunt:**

Edit `live/staging/terragrunt.hcl`:

```hcl
inputs = {
  enable_https         = true
  acm_domain_name      = "app.example.com"                    # Your domain
  route53_zone_id      = "Z1234567890"                        # Your zone ID

  # Optional: Add wildcard support
  acm_subject_alternative_names = ["*.example.com"]

  # ... other inputs
}
```

3. **Deploy:**

```bash
cd live/staging
terragrunt apply
```

**What happens automatically:**
1. Terraform creates ACM certificate request
2. Terraform creates DNS validation records in Route53
3. ACM validates the certificate (takes 1-5 minutes)
4. ALB listener configured with the certificate
5. HTTP → HTTPS redirect enabled

4. **Create DNS Record for Your App:**

After deployment, point your domain to the ALB:

```bash
# Get the ALB DNS name
cd live/staging
terragrunt output alb_dns_name
```

Create DNS record in Route53:
- **Type:** A (Alias)
- **Name:** `app.example.com`
- **Alias Target:** Your ALB DNS name
- **Alias Hosted Zone:** (auto-detected for ALB)

Or use Terraform to automate this:

```hcl
# Add to your terragrunt.hcl or create a separate Route53 module
resource "aws_route53_record" "app" {
  zone_id = "Z1234567890"  # Your zone ID
  name    = "app.example.com"
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}
```

5. **Access Your Application:**

```bash
# HTTPS (recommended)
https://app.example.com

# HTTP (auto-redirects to HTTPS)
http://app.example.com
```

---

## Security Best Practices

### TLS Configuration

The ALB uses the modern **TLS 1.3** policy:
- Policy: `ELBSecurityPolicy-TLS13-1-2-2021-06`
- Supports: TLS 1.3, TLS 1.2
- Strong cipher suites only

### Certificate Auto-Renewal

ACM certificates auto-renew automatically:
- Renewal starts 60 days before expiration
- No manual intervention needed
- Validation via Route53 DNS records

### HTTP Security Headers (Optional Enhancement)

Consider adding these headers in your nginx configuration:

```nginx
# In your nginx config
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

---

## Troubleshooting

### Certificate Validation Stuck

If certificate validation takes more than 10 minutes:

1. **Check Route53 records:**
```bash
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890 | grep _acm
```

2. **Check NS records at registrar:**
```bash
dig NS example.com
```

Ensure NS records match your Route53 name servers.

### Certificate Not Being Used

1. **Check HTTPS is enabled:**
```bash
cd live/staging
terragrunt output https_enabled
```

2. **Verify certificate ARN:**
```bash
terragrunt output acm_certificate_arn
```

3. **Check certificate status:**
```bash
aws acm describe-certificate --certificate-arn <your-arn>
```

### DNS Not Resolving

```bash
# Test DNS resolution
dig app.example.com

# Check Route53 record
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890 | grep app.example.com
```

---

## Example Configurations

### Example 1: Development (No HTTPS)

```hcl
inputs = {
  enable_https = false
  # No certificate needed
}
```

### Example 2: Staging (Manual Certificate)

```hcl
inputs = {
  enable_https        = true
  alb_certificate_arn = "arn:aws:acm:us-west-2:123:certificate/abc-123"
}
```

### Example 3: Production (Auto Certificate + Wildcard)

```hcl
inputs = {
  enable_https                  = true
  acm_domain_name               = "app.example.com"
  acm_subject_alternative_names = ["*.example.com", "example.com"]
  route53_zone_id               = "Z1234567890"
}
```

---

## Architecture Changes with HTTPS

### Without HTTPS:
```
Internet → ALB (HTTP:80) → EC2 Instances (HTTP:80)
```

### With HTTPS:
```
Internet → ALB (HTTP:80) → [301 Redirect] → HTTPS:443 → EC2 Instances (HTTP:80)
         ↓
       (HTTPS:443) → EC2 Instances (HTTP:80)
```

**Note:** SSL/TLS termination happens at the ALB. Traffic from ALB to EC2 instances remains HTTP (within VPC, secure).

---

## Related Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_https` | Enable HTTPS listener | `false` |
| `alb_certificate_arn` | Manual certificate ARN | `""` |
| `acm_domain_name` | Domain for auto-certificate | `""` |
| `acm_subject_alternative_names` | Additional domains | `[]` |
| `route53_zone_id` | Route53 zone for validation | `""` |
