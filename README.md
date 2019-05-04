# helm-samba4
## Helm Chart and Dockerfile for Samba4 based on alpine:latest.

This Chart is fully-featured and enables some neat features :

 * Shares `persistentVolume`s, `hostPath`s, `flexVolume`s and arbritrary volumes that might not even have k8s drivers yet via samba/cifs
 * Creates users based on values provided or doesn't
 * Works with it's own automated build docker image or with the #1 hit for samba on dockerhub (even though that has no autobuild, has only ever been built once and only has a :latest tag.  You've been warned!)

## Users

The chart will provision you smb users automatically based on the `samba.users` values.  This is the recommended way of dealing with users using this chart.  example `values.yaml` settings for the `samba.users` block :

```YaML
samba:
  users:
  - username: myuser
    password: hunter2
  - username: myotheruser
    password: CorrectBatteryHorseStaple
```
Setting these values via a secrets management system is recommended.

## Storage

Most of this chart's cleverness is around the volume selection.  If you set `persistence.enabled` to true, it then looks at the value of `persistence.type` and acts accordingly.  The data volume is mounted in the container under `/data`.

| `persistence.type` | Description | Behaviour |
|--------------------|-------------|-----------|
| `pvc` | Use an existing or new PVC for data | If `persistence.pvc.existingClaim` is set, then the chart uses that.  If not, it creates a PVC based on `persistence.pvc.size` (default 8Gi), `persistence.pvc.accessMode` (default ReadWriteOnce), and `persistence.pvc.storageClass` (default blank, default class for your cluster) |
| `hostPath` | Use a `hostPath` type mount | Suitable for single-machine clusters or setups that have a host-based shared filesystem (e.g. nfs).  Looks at `persistence.pvc.hostPath` to create the mount. _*NOTE*_: using this you must also set `privatePersistence` up with a different path or different class of persistence or your smb passwords will be accessible via smb! |
| `flexVolume` | Use a `flexVolume` driver to provide persistence | If you are using an out-of-tree persistent data plugin, you will want this.  It will set a flexVolume mount using what yaml you provide in `persistence.flexVolume` directly |
| `other` | Use something unexpected | As with the `flexVolume` option, this simply allows you to put raw yaml in `persistence.other` and it will be used directly.  This obviously is very powerful but can leave you with very broken deployment objects. |

### `privatePersistence`

This image optionally uses a second mount for samba's "private" storage (`/var/lib/samba` and `/etc/passwd`) so users can be persisted between pod restarts.  If you wish to manage your users manually and allow them to change their own passwords for instance you may set `privatePersistence.enabled` to `true`

If you don't specify any other `privatePersistence` options, the chart does it's best to do something appropriate.  If you want to set options, it's exactly the same as the above `persistent` storage.

These are the rules it uses -

 * if you use hostPath for your main storage, the privatePersistence is mounted as `.smbprivate/` underneath it.
 * if you use `persistence.type.pvc` without setting `privatepersistence.pvc.size`, it uses a default of `20Mi` for private data
 * if you use `persistence.pvc.existingClaim` and not `privatePersistence.pvc.existingClaim`, the chart will attempt to use defaults for the pvc that it creates.
 * if you use `flexVolume` or `other` for the `persistence` type and don't set a `privatePersistence` block of the same type, the chart will simply fail

## `smb.conf`

The container's `smb.conf` is loaded in via a configmap and is templated for some basic settings (single share).

Much like the `samba.users` config above, you can create `samba.global.extraLines` and `samba.share.extraLines` and add extra entries for the lines you wish to add.  For example your `values.yaml` may contain something like this (don't use that setting btw unless you know exactly what you're doing!):

```
samba:
  global:
    workgroup: HOMEGROUP
    extraLines:
    - key: fake oplocks
      value: yes
    - key: fstype
      value: Samba 
  share:
    nameOverride: bigdisk
    extraLines:
    - key: force user
      value: martyn
    - key: valid users
      value: martyn
```
 
## Other configuration

| Parameter | Description | Default |
|-----------|-------------|-------- |
| `affinity` | Affinity block for [Node Affinity](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/) | `{}` |
| `fullnameOverride` | Full name override for helm chart | `""` |
| `image.lacksK8sScript` | Image is a plain alpine image with only samba starting in foreground mode, we need a script adding | `false` |
| `image.pullPolicy` | Standard kubernetes option | `"IfNotPresent"` |
| `image.repository` | Which image to pull. Recommend you don't change this, but e.g. `stanback/alpine-samba` also works | `"imartyn/samba4k8s"` |
| `image.tag` | Which tag of the above image to use | `"stable"` |
| `livenessProbe.enabled` | Check for samba liveness using smbclient | `true` |
| `nameOverride` | Full name override for helm chart | `""` |
| `nodeSelector` | `nodeSelector` block for [Node Affinity](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/) | `{}` |
| `persistence.enabled` | Persist `/data/` across pod restarts | `false` |
| `persistence.type` | Must be set to one of `pvc`,`hostPath`,`flexVolume` or `other` if `persistence.enabled` is `true` | `"emptyDir"` |
| `persistence.pvc.existingClaim` | Share an existing PVC via samba | Create a new pvc (dependant on `persistence.enabled`) |
| `persistence.pvc.accessMode` | If `persistence.pvc.existingClaim` is NOT set and `persistence.enabled` is AND `persistence.type` is `"pvc"`, chart creates a PVC with this `accessMode` | `"readWriteOnce"` |
| `persistence.pvc.size` | If `persistence.pvc.existingClaim` is NOT set and `persistence.enabled` is AND `persistence.type` is `"pvc"`, chart creates a PVC with this `size` | `"8Gi"` |
| `persistence.pvc.storageClass` |  If `persistence.pvc.existingClaim` is NOT set and `persistence.enabled` is AND `persistence.type` is `"pvc"`, chart creates a PVC with this `storageClass` | `"-"` |
| `persistence.other` | If `persistence.type` is `"other"`, deployment references a Volume with this block of yaml | `{}` |
| `persistence.flexVolume` | If `persistence.type` is `"other"`, deployment references a Volume of type `flexVolume` with this block of yaml | `{}` |
| `privatePersistence.*` | see storage description in readme. | `{}` |
| `privatePersistence.pvc.size` | see storage description in readme. | `"20Mi"` |
| `replicaCount` | Number of pods that the Deployment should launch.  NOTE: locking may be an issue if you have more than one, and you must use a storage that works from more than one pod. | `1` |
| `resources` | `resources` block for pod resources as described in [the Kubernetes documentation](https://kubernetes.io/docs/tasks/configure-pod-container/assign-cpu-resource/)  | `{}` |
| `samba.global.workgroup` | Set the `"WORKGROUP"` that the samba server appears in.  Note that these images don't run nmbd so it's mostly irellevant. | `"WORKGROUP"` |
| `samba.global.server_string` | The string that samba announces itself as | `"%h server (Samba, Alpine)"` |
| `samba.global.security` | This maps to the samba `[global]` section's `security` flag | `"user"` |
| `samba.global.map_to_guest` | This maps to the samba `[global]` section's `map_to_guest` flag | `"Bad User"` |
| `samba.global.encrypt_passwords` | This maps to the samba `[global]` section's `encrypt_passwords` flag | `"yes"` |
| `samba.global.server_role` | This maps to the samba `[global]` section's `server_role` flag | `"standalone"` |
| `samba.global.smb_ports` | This maps to the samba `[global]` section's `smb_ports` flag | `"445` |
| `samba.global.log_level` | This maps to the samba `[global]` section's `log_level` flag | `"3"` |
| `samba.global.extraLines` | Extra lines to add to the `[global]` section in an array of `key`: `some_param`, `value`:`some_value` form that becomes `some_param = some_value` | blank
| `samba.share.nameOverride` | Set the share name that is the exposed storage | `"data"` |
| `samba.share.comment` | Set the comment that is listed alongside the share | `"ZFS"` |
| `samba.share.browseable` | Does the share become visible when you visit the server with an smb client | `"yes"` |
| `samba.share.writable` | Is the share writeable by default (i.e. not readonly) | `"yes"` |
| `samba.share.extraLines` | Extra lines to add to the `[<<share>>]` section in an array of `key`: `some_param`, `value`:`some_value` form that becomes `some_param = some_value` | blank
| `samba.users` | Array of `username:` and `password:` items that are created on startup.  Stored in a kubernetes secret.  See "Users" section of the readme.md | `[]` |
| `service.port` | Service port that is advertised to the cluster | `445` |
| `service.type` | Service type to expose to the cluster (or the world if you are that foolish) | `"ClusterIP"` |
| `tolerations` | `tolerations` block for [Node Affinity](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/) | `[]` |

## Why?
Because why not?  The use cases are actually multiple:
 * Home/LAB setup with windows clients
 * Kubernetes actually allows you to use volumes of type cifs, this might be a useful way of sharing a PVC in an environment where you have no `ReadWriteMany` cloudprovider
 * A lot of backup applications have SMB as a target, having SMB storage in your cluster so you only ever have to back up your PVCs is quite nice.
