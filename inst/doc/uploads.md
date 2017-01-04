Data Uploads for sensorgnome.org
===

We use a patched [ProjectSend](https://github.com/ignacionelson/ProjectSend) as the server-side upload host.
To facilitate user transition, we've allowed it to use password hashes from the dekiwiki
sensorgnome.org site by creating these triggers on the sensorgnome database:

```sql
   create trigger update_sg_user after update on users for each row update data_uploads.sg_users set user=new.user_name, password=concat('!', ifnull(new.user_newpassword, new.user_password)), name=new.user_real_name, email=new.user_email, created_by='sg.data.upload', timestamp=current_timestamp() where id=new.user_id;

 create trigger copy_sg_user after insert on users for each row insert into data_uploads.sg_users (id, user, password, name, email, created_by, timestamp) values (new.user_id, new.user_name, concat('!', ifnull(new.user_newpassword, new.user_password)), new.user_real_name, new.user_email, 'sg.data.upload', current_timestamp());

```

The patched ProjectSend recognizes a leading '!' on a password hash to
mean it was generated using dekiwiki/mindtouch's weak hashing function:

```php
  $hash = md5($logged_id . '-' . md5($password));
```
