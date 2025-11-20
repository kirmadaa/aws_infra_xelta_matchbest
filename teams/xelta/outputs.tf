output "cdn_domain_name" {
  value = try(module.cdn[0].cdn_dns_name, "")
}

output "http_api_endpoint_us_east_1" {
  value = try(module.us_east_1_stack[0].http_api_endpoint, "")
}

output "http_api_endpoint_eu_central_1" {
  value = try(module.eu_central_1_stack[0].http_api_endpoint, "")
}

output "http_api_endpoint_ap_south_1" {
  value = try(module.ap_south_1_stack[0].http_api_endpoint, "")
}

output "websocket_api_endpoint_us_east_1" {
  value = try(module.us_east_1_stack[0].websocket_api_endpoint, "")
}

output "websocket_api_endpoint_eu_central_1" {
  value = try(module.eu_central_1_stack[0].websocket_api_endpoint, "")
}

output "websocket_api_endpoint_ap_south_1" {
  value = try(module.ap_south_1_stack[0].websocket_api_endpoint, "")
}
