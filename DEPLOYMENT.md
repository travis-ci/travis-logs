Setting up FileStorage on ubuntu 14.04 to samba
-----------------------------------------------

* set `log_storage_provider` to `file_storage` in
  `lib/travis/logs/config.rb`
* configure file_sotrage settings in `lib/travis/logs/config.rb`

      file_storage:  { root_path: '/var/tmp/travis-logs/' }

* install mount.cifs: `apt-get install cifs-utils`
* create directory for storing logs and add exclusive access

     LOG_DIR=/mnt/auto_test_testing
     mkdir -p $LOG_DIR
     sudo chown <travis-user>.<travis-user> $LOG_DIR
     chmod o+rwx $LOG_DIR

* fill into /etc/fstab the following line

     #chage UNC and mount point!
     //10.1.0.1/AutoTestsTesting /mnt/auto_tests_testing cifs username=USER,password=PASSWD,sec=ntlm,file_mode=0777,dir_mode=0777 0 0

   * in case of some problems the options should be extended by string: iocharset=utf8
* type `sudo mount -a` (no restart should be required and share should be mounted with write access for non-root users)

