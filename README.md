user-script
=====

![Travis Status](https://travis-ci.org/ZCloud-Firstserver/user-script.png?branch=master)

See pro tips. [Continuous convergence with the chef-solo on the joyent smartmachine and meta-data API.](https://coderwall.com/p/9gk3ag)

Overview
----


SmartMachineをプロビジョン時にChef-SoloのCronを仕込んで継続的に実行する、一回限りのオプションにも対応。


Metadata
----

利用可能メタデータ一覧

- zcloud_app: アプリケーション名、**必須**
- zcloud_app_repo: アプリケーションリポジトリのGit、**必須**
- zcloud_app_ref: リモートのbranch名、省略時は`master`
- zcloud_app_once: 初回のみChefSoloを実行、2度目以降は何もしない。キーがあれば値はなんでも良い。
- user-data: Chefのノード用Json、必要ない場合は文字列のブレス `{}`、**必須**

- zcloud_hostname: hostnameに使用出来る文字、省略時はIPアドレス＋zonename
- zcloud_timezone： `sm-list-timezones` で取得できるもの、デフォルトはJapan
- zcloud_notify_to： カンマ区切りメールアドレス

Chef−Solo
----

#### Chef-repo

`Meadatta: zcloud_app_repo` にセットされたgitリポジトリをクローンし、以降Masterが継続的にフェッチされる。

#### run_list

`Meadatta: zcloud_app`にセットされたロール名でChef-Soloが実行される `role[${zcloud_app}]`

#### override_attributes(node.json)

`Meadatta: user-data`にOverride用のJsonを格納するとChef-soloが取り込んでくれる(`-j` オプション)。


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

Aplication Examples
----

User-Scriptと連携するサンプルリポジトリを用意しました。

- **Dokuwiki** : `[https://github.com/ZCloud-Firstserver/application_dokuwiki](https://github.com/ZCloud-Firstserver/application_dokuwiki)

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
