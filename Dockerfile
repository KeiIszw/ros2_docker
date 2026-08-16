FROM ros:humble-ros-base-jammy

ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        build-essential \
        git \
        less \
        python3-colcon-common-extensions \
        python3-pip \
        python3-pytest \
        python3-rosdep \
        python3-vcstool \
        ros-humble-robot-state-publisher \
        ros-humble-ros2-control \
        ros-humble-ros2-controllers \
        ros-humble-joy \
        ros-humble-xacro \
        sudo \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/bash "${USERNAME}" \
    && printf '%s ALL=(root) NOPASSWD:ALL\n' "${USERNAME}" > "/etc/sudoers.d/${USERNAME}" \
    && chmod 0440 "/etc/sudoers.d/${USERNAME}"

COPY ros_entrypoint.sh /usr/local/bin/operasim_ros_entrypoint.sh
RUN chmod 0755 /usr/local/bin/operasim_ros_entrypoint.sh \
    && printf '%s\n' \
        'source /opt/ros/humble/setup.bash' \
        '[ ! -f "$HOME/ros2_ws/install/setup.bash" ] || source "$HOME/ros2_ws/install/setup.bash"' \
        >> "/home/${USERNAME}/.bashrc" \
    && chown "${USER_UID}:${USER_GID}" "/home/${USERNAME}/.bashrc"

ENV DEBIAN_FRONTEND=
WORKDIR /home/${USERNAME}/ros2_ws
USER ${USERNAME}

ENTRYPOINT ["/usr/local/bin/operasim_ros_entrypoint.sh"]
CMD ["bash"]
