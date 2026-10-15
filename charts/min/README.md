# min

A ConfigMap and nothing else. `message` and `owner` from the values file are written into the ConfigMap data.

```bash
helm install min ./charts/min --set message=hello --set owner=nuon
```
