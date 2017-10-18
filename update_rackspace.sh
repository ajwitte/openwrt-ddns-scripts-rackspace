[ -z "$domain" ]   && write_log 14 \
  "Service section not configured correctly! Missing 'domain'"
[ -z "$username" ] && write_log 14 \
  "Service section not configured correctly! Missing 'username'"
[ -z "$password" ] && write_log 14 \
  "Service section not configured correctly! Missing 'password' (Rackspace API key)"
[ -z "$param_opt" ] && write_log 14 \
    "Service section not configured correctly! Missing 'param_opt' (Rackspace Domain, probably your second-level domain)"

local rs_identity_json=`curl -s https://identity.api.rackspacecloud.com/v2.0/tokens \
  -X POST \
  -d "{\"auth\":{\"RAX-KSKEY:apiKeyCredentials\":{\"username\":\"$username\", 
      \"apiKey\":\"$password\"}}}" -H "Content-type: application/json"` || return 1

local rs_token=`jsonfilter -s "$rs_identity_json" -e '@.access.token.id'` || return 1
local rs_endpoint=`jsonfilter -s "$rs_identity_json" \
  -e '@.access.serviceCatalog[@.name="cloudDNS"].endpoints[0].publicURL'` || return 1

local rs_domainid=`curl -s "$rs_endpoint/domains" \
  -H "X-Auth-Token: $rs_token" -H "Accept: application/json" \
  | jsonfilter -e "@.domains[@.name=\"$param_opt\"].id"` || return 1

local rs_type='A'
[ "$use_ipv6" -eq 1 ] && rs_type='AAAA'
local rs_recordid=`curl -s "$rs_endpoint/domains/$rs_domainid/records" \
  -H "X-Auth-Token: $rs_token" -H "Accept: application/json" \
  | jsonfilter -e "@.records[@.name=\"$domain\" && @.type=\"$rs_type\"].id"` || return 1

local rs_callback=`curl -s "$rs_endpoint/domains/$rs_domainid/records/$rs_recordid" \
  -X PUT -d "{\"data\":\"$__IP\"}" \
  -H "X-Auth-Token: $rs_token" -H "Content-type: application/json" \
  | jsonfilter -e "@.callbackUrl"` || return 1

local rs_status="INITIALIZED"
while [[ $rs_status == "INITIALIZED" -o $rs_status == "RUNNING" ]] ; do
  rs_status=`curl -s "$rs_callback" \
    -H "X-Auth-Token: $rs_token" -H "Accept: application/json" \
    | jsonfilter -e "@.status"` || return 1
  sleep 1
done

[ $rs_status == "COMPLETED" ]
return $?
