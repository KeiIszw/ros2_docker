# OperaSim-PhysX 用 ROS 2 Humble 環境

Unity の建機シミュレータ `~/github/OperaSim-PhysX` を ROS 2 Humble から制御するための
Docker 環境です。ホストの `~/ros2_ws` をコンテナ内の `/home/ros/ros2_ws` にマウントし、
Unity Robotics の ROS TCP Endpoint を `127.0.0.1:10000` で公開します。

## ワークスペース

既定では、ホストの `~/ros2_ws` をコンテナの `/home/ros/ros2_ws` にマウントします。
現在の `src` には次の ROS 2 パッケージがあります。

- `com3_msgs`: COM3 の message/action 定義
- `ros_tcp_endpoint`: Unity ROS TCP Connector の ROS 2 Endpoint
- `scratch_hci_bridge`: Scratch HCI と OperaSim の ROS 2 topic を接続する bridge
- `tb20e_control`: TB20e 用 `ros2_control` hardware interface

`ros2.repos` に登録されたソースを再取得する場合は、空の `~/ros2_ws/src` に対して
次を実行できます。

```bash
cd ~/ros2_docker
vcs import ~/ros2_ws/src < ros2.repos
```

## ビルド

Docker image を作成し、コンテナ内で `src` 以下の全パッケージの依存関係を導入して
ビルドします。コマンドはホスト側で実行してください。

```bash
cd ~/ros2_docker
docker compose build
docker compose run --rm --no-deps ros2 bash -c '
  set -e
  source /opt/ros/humble/setup.bash
  cd /home/ros/ros2_ws
  rosdep update
  rosdep install --from-paths src --ignore-src --rosdistro humble -y
  colcon build --symlink-install
'
```

生成される `build`、`install`、`log` はホストの `~/ros2_ws` に保存されます。
ビルド成功時は最後に `Summary: 4 packages finished` と表示されます。パッケージ数は
`src` の内容によって変わります。

`permission denied while trying to connect to the docker API` と表示される環境では、
上記および以降の `docker` コマンドを `sudo docker ...` として実行してください。
現在の構成はコンテナユーザーをホストの UID/GID に合わせるため、`sudo docker compose`
を使用してもワークスペースの生成物は通常ユーザー所有になります。

## Endpoint の起動

```bash
cd ~/ros2_docker
docker compose up -d
docker compose logs -f ros2
```

Unity の `Robotics > ROS Settings` は次の値にします。

- ROS IP Address: `127.0.0.1`
- ROS Port: `10000`
- Protocol: `ROS 2`

現在の OperaSim-PhysX に含まれる `ROSConnectionPrefab` は IP と Port が上記の値です。
Endpoint を止める場合は `docker compose down` を実行します。

## TB20e の起動

先に Unity で TB20e のシーンを Play し、4 本の角度 topic が配信される状態にします。
別ターミナルで次を実行してください。

```bash
cd ~/ros2_docker
docker compose exec ros2 bash
ros2 topic echo /current_boom_angle --once
ros2 launch tb20e_control tb20e_control.launch.py
```

hardware の activate 時に全軸の角度 feedback が必要なため、Unity が停止した状態で
`tb20e_control.launch.py` を起動すると初期化が timeout します。

別ターミナルから controller 状態を調べる例です。

```bash
cd ~/ros2_docker
docker compose exec ros2 bash -ic 'ros2 control list_controllers'
docker compose exec ros2 bash -ic 'ros2 topic echo /joint_states --once'
```

軌道 goal の例です（角度は radian）。

```bash
docker compose exec ros2 bash -ic "ros2 action send_goal --feedback \
  /tb20e_controller/follow_joint_trajectory \
  control_msgs/action/FollowJointTrajectory \
  '{trajectory: {joint_names: [swing_joint, boom_joint, arm_joint, bucket_joint], points: [{positions: [0.0, -0.35, 1.40, 0.52], velocities: [0.0, 0.0, 0.0, 0.0], time_from_start: {sec: 5}}]}}'"
```

## ソース変更後の再ビルド

実行中の TB20e launch を終了してから、次を実行します。Unity は起動したままでも構いません。

```bash
cd ~/ros2_docker
docker compose exec ros2 bash -ic \
  'source /opt/ros/humble/setup.bash && cd /home/ros/ros2_ws && colcon build --symlink-install --packages-select tb20e_control'
```

既に開いている shell は `source ~/ros2_ws/install/setup.bash` を再実行してください。
