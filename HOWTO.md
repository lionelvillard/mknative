# HOW TOs

## How to dump envoy configuration

1. Edit the bootstrap configuration to allow `config_dump`:

```shell
kubectl edit -n kourier-system cm kourier-bootstrap 
```

Before:

`regex: '/(certs|stats(/prometheus)?|server_info|clusters|listeners|ready)?'`

After:
`regex: '/(config_dump|certs|stats(/prometheus)?|server_info|clusters|listeners|ready)?'`

2. Restart envoy:

```shell
kubectl rollout restart deployment -n kourier-system 3scale-kourier-gateway 
```

3. Port forward the admin 

```shell
kubectl port-forward -n kourier-system deployment/3scale-kourier-gateway 9000
```
