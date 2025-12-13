# Geo-Routing Worker Script
resource "cloudflare_worker_script" "geo_router" {
  account_id = var.account_id
  name       = "xelta-${var.environment}-geo-router"
  content    = <<-EOT
    addEventListener('fetch', event => {
      event.respondWith(handleRequest(event.request))
    })

    async function handleRequest(request) {
      const url = new URL(request.url);
      const country = request.cf.country;

      // Map continents/countries to regions (ALBs)
      // Note: We use the 'origin-' subdomains we created
      const regionMapping = {
        'EU': 'eu-central-1',
        'AS': 'ap-south-1',
        'NA': 'us-east-1',
        'SA': 'us-east-1',
        'OC': 'ap-south-1',
        'AF': 'eu-central-1'
      };

      // Simplified mapping based on continent
      const continent = request.cf.continent || 'AS'; // Default to Asia/AP-South-1 if unknown

      let targetRegion = 'ap-south-1'; // Global default

      if (regionMapping[continent]) {
        targetRegion = regionMapping[continent];
      }

      // Explicit country overrides if needed (example)
      // if (country === 'US') targetRegion = 'us-east-1';

      // Construct the new origin URL
      // We point to origin-region.xelta.ai which is a CNAME to the ALB
      const originHostname = "origin-" + targetRegion + ".${var.domain_name}";

      url.hostname = originHostname;
      // Protocol is HTTPS between Cloudflare and Worker, but we can fetch HTTP from Origin if needed.
      // However, our origins are "DNS Only" CNAMEs to ALBs listening on Port 80.
      // So we must fetch HTTP.
      url.protocol = "http:";
      url.port = "80";

      const newRequest = new Request(url, request);

      // We might need to override the Host header if the ALB expects it,
      // but ALBs usually expect the Host header to match their listener rules.
      // If ALB is just forwarding default, it might not matter.
      // But standard practice is to keep the original Host header so the app knows the domain.
      // But if we keep Host: xelta.ai, and fetch http://origin-us.xelta.ai,
      // the request goes to ALB IP with Host: xelta.ai.
      // The ALB listener must accept Host: xelta.ai.

      return fetch(newRequest);
    }
  EOT

  module = false
}

# Bind Worker to Route (Root)
resource "cloudflare_worker_route" "main" {
  zone_id     = var.zone_id
  pattern     = "${var.domain_name}/*"
  script_name = cloudflare_worker_script.geo_router.name
}

# Bind Worker to Route (WWW)
resource "cloudflare_worker_route" "www" {
  zone_id     = var.zone_id
  pattern     = "www.${var.domain_name}/*"
  script_name = cloudflare_worker_script.geo_router.name
}

# Root Record (Proxied) - Required for Worker to trigger
# Points to a dummy IP because the Worker intercepts it.
resource "cloudflare_record" "root" {
  zone_id = var.zone_id
  name    = "@"
  value   = "192.0.2.1" # Dummy IP
  type    = "A"
  proxied = true
}

# WWW Record (Proxied)
resource "cloudflare_record" "www" {
  zone_id = var.zone_id
  name    = "www"
  value   = var.domain_name
  type    = "CNAME"
  proxied = true
}

# Origin Records (DNS Only / Grey Cloud)
# These point to the actual ALBs
resource "cloudflare_record" "origins" {
  for_each = var.origins

  zone_id = var.zone_id
  name    = "origin-${each.key}" # e.g., origin-us-east-1
  value   = each.value           # ALB DNS Name
  type    = "CNAME"
  proxied = false                # DNS Only - Important!
}
