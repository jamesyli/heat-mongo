# Heat template to provision a mongo cluster on OpenStack

```bash
heat stack-create -f ./docker-stack.yml -P db_size=2 -P key=<key_name> <stack_name>
```
