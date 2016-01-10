mysql02 Cookbook
================
MySQLサーバーのマスター＆レプリカを構成するクックブック

MySQL 5.6.28 をダウンロードして、マスターとスレーブのサーバー構成できます。
データのレプリカは、このクックブックを適用することで生成されるシェルを実行することで、
簡単にスレーブサーバ上にレプリカを構成することができます。

一つのマスターに対して複数のスレーブを作りデータのレプリカを増やしていけます。


Requirements
------------
###オペレーティングシステム
* CentOS 6.x - Minimal Install (64 bit)
* CentOS 7.x - Minimal Install (64 bit)
* Ubuntu Linux 14.04 LTS Trusty Tahr - Minimal Install (64 bit)

###パッケージ
* hostsfile https://github.com/customink-webops/hostsfile

###プロビジョニング・スクリプト
OSに対応したプロビジョニング・スクリプトを利用します。

* CentOS 6.x https://github.com/takara9/ProvisioningScript/blob/master/centos_basic_config
* CentOS 7.x https://github.com/takara9/ProvisioningScript/blob/master/centos7_basic_config
* Ubuntu 14.04 https://github.com/takara9/ProvisioningScript/blob/master/ubuntu_basic_config


Attributes
----------

#### mysql01::default
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>

<tr>
  <td>default["mysql"]["root_password"]</td>
  <td>Text</td>
  <td>MySQLのrootパスワード</td>
  <td>passw0rd</td>
</tr>

<tr>
  <td>default["mysql"]["server_id"]</td>
  <td>Number (1 - 65536)</td>
  <td>MySQL ServerのID 一意であること</td>
  <td>100</td>
</tr>

<tr>
  <td>default["mysql"]["bin_log"]</td>
  <td>Text</td>
  <td>同期用のログ置き場</td>
  <td>/data2/bin_log</td>
</tr>

<tr>
  <td>default["mysql"]["master_ip"]</td>
  <td>Text</td>
  <td>マスターサーバーのプライベートIP</td>
  <td>必須設定</td>
</tr>

<tr>
  <td>default["mysql"]["replica_ip1"]</td>
  <td>Text</td>
  <td>スレーブサーバーのプライベートIP</td>
  <td>必須設定</td>
</tr>

<tr>
  <td>default["mysql"]["replica_username"]</td>
  <td>Text</td>
  <td>レプリカ実行ユーザー名</td>
  <td>replica</td>
</tr>

<tr>
  <td>default["mysql"]["replica_password"]</td>
  <td>Text</td>
  <td>パスワード</td>
  <td>replica</td>
</tr>

<tr>
  <td>default["mysql"]["role"]</td>
  <td>Text</td>
  <td>役割 master/slave 択一</td>
  <td>master</td>
</tr>

</table>


利用法
-----
#### mysql02::default

Knife などを利用して、実行する場合は、run_listに追加する。

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[mysql02]"
  ]
}
```

スタンドアロンで、適用を推進する場合は、以下のコマンドで下準備する。

```
# curl -L https://www.opscode.com/chef/install.sh | bash
# knife cookbook create dummy -o /var/chef/cookbooks
# cd /var/chef/cookbooks
# git clone https://github.com/customink-webops/hostsfile
# git clone https://github.com/takara9/mysql02
```
材料が集まったら、属性(Attribute)を環境に合わせて編集する。

マスター側の編集例　/var/chef/cookbooks/mysql02/attributes/default.rb

```
default["mysql"]["root_password"]    = 'passw0rd'
default["mysql"]["server_id"]        = '100'        <-- ユニークな番号をセット
default["mysql"]["bin_log"]          = '/data2/bin_log'
default["mysql"]["master_ip"]        = '10.132.253.30'  <--マスタ側のIP
default["mysql"]["replica_ip1"]      = '10.132.253.38'  <--スレーブ側のIP
default["mysql"]["replica_username"] = 'replica'
default["mysql"]["replica_password"] = 'replica'
default["mysql"]["role"]             = 'master' <-- 役割 マスターの場合
```

スレーブ側の編集例　/var/chef/cookbooks/mysql02/attributes/default.rb

```
default["mysql"]["root_password"]    = 'passw0rd'
default["mysql"]["server_id"]        = '101'  <-- マスターと異なるIDを付与する
default["mysql"]["bin_log"]          = '/data2/bin_log'
default["mysql"]["master_ip"]        = '10.132.253.30'
default["mysql"]["replica_ip1"]      = '10.132.253.38'
default["mysql"]["replica_username"] = 'replica'
default["mysql"]["replica_password"] = 'replica'
default["mysql"]["role"]             = 'slave'  <-- 役割 レプリカの場合
```

編集が終了したら、次のコマンドでクックブックを適用する。

```
# chef-solo -o mysql02
```

マスターノードは、以下のコマンドができているので、実行する。

```
# /root/data_sync.sh

```

スレーブノード側は、マスター側の設定が完了したら、以下のコマンドが作成されるので、実行する。

```
# /root/start_replica.sh

```

動作確認
----------
マスター側からの確認方法は、MySQLサーバーにログインして、スレーブのリストを表示して、確認する。

```
# mysql -u root -ppassw0rd
```

```
mysql> show slave hosts;
+-----------+------+------+-----------+--------------------------------------+
| Server_id | Host | Port | Master_id | Slave_UUID                           |
+-----------+------+------+-----------+--------------------------------------+
|       101 |      | 3306 |       100 | e902a111-b735-11e5-b835-06b648cd4b4f |
+-----------+------+------+-----------+--------------------------------------+
1 row in set (0.00 sec)
```


スレーブ側からの確認方法は、次のコマンドを実行して、エラーが無い事を確認する。

```
mysql> show slave status \G;
```

以下の様にエラーが無ければ、マスターとスレーブの連携が確立されている。

```
************************************************
Slave_IO_State: Waiting for master to send event
中略
Last_IO_Errno: 0
Last_IO_Error: 
中略
```

エラー発生時の表示例

```
************************************************
Slave_IO_State: 
中略
Last_IO_Errno: 1593
Last_IO_Error: Fatal error: The slave I/O thread stops because master and slave have equal MySQL server UUIDs; these UUIDs must be different for replication to work.
中略
```


レプリカの追加
---------------

このクックブックでは、容易にスレーブサーバーを追加することができます。
追加するサーバーのアトリビュートを次の例に従って編集します。

対象ファイル /var/chef/cookbooks/mysql02/attributes/default.rb

```
default["mysql"]["root_password"] = 'passw0rd'
default["mysql"]["server_id"] = '104'          <-- 既存のサーバと重複しない一意のID
default["mysql"]["bin_log"] = '/data2/bin_log'
default["mysql"]["master_ip"] = '10.132.253.30'   <-- マスターのIPアドレス
default["mysql"]["replica_ip1"] = '10.132.253.39' <-- 追加サーバのIPアドレス
default["mysql"]["replica_username"] = 'replica'
default["mysql"]["replica_password"] = 'replica'
default["mysql"]["role"] = 'slave'  <-- スレーブ（レプリカ）を選択
```

編集が終わったら、クックブックを適用します。そして、マスターサーバーの以下の
/root/data_sync.shファイルのREPLICA_IPを追加するIPアドレスに変更します。

```
#!/bin/bash

REPLICA_IP=10.132.253.38  <-- 追加するサーバーのIPアドレス
sed -e "s/__REPLICA_IP__/${REPLICA_IP}/" setup_master.sql.tmp > setup_master.sql
以下省略
```

マスターサーバー側で、次のコマンドを実行して、MySQLのデータを転送します。

```
[root@db1 ~]# /root/data_sync.sh 
```

スレーブサーバー側で、次のシェルを実行します。

```
[root@db3 ~]# /root/start_replica.sh 
```

これでレプリカサーバーが追加されました。確認するにはmysqlのクライアントから、次の様に実行します。

```
mysql> show slave hosts;
+-----------+------+------+-----------+--------------------------------------+
| Server_id | Host | Port | Master_id | Slave_UUID                           |
+-----------+------+------+-----------+--------------------------------------+
|       102 |      | 3306 |       100 | 9d5fc0c8-b753-11e5-b8f7-06b648cd4b4f |
|       104 |      | 3306 |       100 | 932b13f5-b761-11e5-b952-06d41931291a |
+-----------+------+------+-----------+--------------------------------------+
2 rows in set (0.00 sec)
```

マスターサーバで実行されたコマンドが、２つのスレーブサーバーに反映される様になります。
一方で、スレーブサーバーで実行された結果は、他のサーバーに伝播しないので注意が必要です。



License and Authors
-------------------
Authors: Maho Takara












