user-script
=====

See pro tips. [Continuous convergence with the chef-solo on the joyent smartmachine and meta-data API.](https://coderwall.com/p/9gk3ag)

Overview
----

SmartMachineをプロビジョン時にChef-SoloのCronを仕込んで継続的に実行する


Metadata
----

require

- zcloud_app: アプリケーション名
- zcloud_app_repo: アプリケーションリポジトリのGit

option

- zcloud_hostname: hostnameに使用出来る文字
- zcloud_timezone： `sm-list-timezones` で取得できるもの、デフォルトはJapan
- zcloud_notify_to： カンマ区切りメールアドレス

Status
----

スクリプト実行段階に応じて`${CURRENTSTATE}`が変化する、レポートメールに記載される。

- initalize
- setup_host
- setup_wrapper
- setup_cronjob
- setup_ohai_plugin
- setup_chef-solo
- initalize_git_repository
- update_git_repository
- execute_chef-solo
- failure_chef-solo
- running

Report
----

以下の場合メールが送信される。

- zcloud_notify_to がセットされている
- chef-solo初回起動時のみ結果を通知
- user-script実行時、途中でエラー終了した場合(初回以降は約10分おき実行)

Contributing
------------

e.g.

1. Fork the repository on Github
2. Create a named feature branch (like `add_component_x`)
3. Write you change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

License and Authors
-------------------
Authors: sawanoboryu@higanworks.com (HiganWorks LLC)

Licensed under the Apache License, Version 2.0 (the "License");