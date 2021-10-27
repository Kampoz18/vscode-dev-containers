FROM continuumio/anaconda3 as upstream

# Update, change owner
RUN conda update -y \
    && conda clean -yaf \
    && groupadd -r conda --gid 900 \
    && find /opt -type d | xargs -n 1 chmod g+s \
    && chmod -R g+w /opt/conda \
    && chown -R :conda /opt/conda

FROM mcr.microsoft.com/vscode/devcontainers/base:0-bullseye
COPY --from=upstream /opt/conda /opt/conda

# Copy library scripts to execute
COPY .devcontainer/library-scripts/*.sh .devcontainer/add-notice.sh .devcontainer/library-scripts/*.env /tmp/library-scripts/

# Setup conda to mirror contents from https://github.com/ContinuumIO/docker-images/blob/master/anaconda3/debian/Dockerfile
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/opt/conda/bin:$PATH
ARG USERNAME=vscode
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends bzip2 libglib2.0-0 libsm6 libxext6 libxrender1 mercurial subversion \
    && apt-get upgrade -y \
    && bash /tmp/library-scripts/add-notice.sh \
    && ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    && echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    && echo "conda activate base" >> ~/.bashrc && \
    && groupadd -r conda --gid 900 \
    && usermod -a -G conda ${USERNAME} \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# [Choice] Node.js version: none, lts/*, 16, 14, 12, 10
ARG NODE_VERSION="none"
ENV NVM_DIR=/usr/local/share/nvm
ENV NVM_SYMLINK_CURRENT=true \
    PATH=${NVM_DIR}/current/bin:${PATH}
RUN bash /tmp/library-scripts/node-debian.sh "${NVM_DIR}" "${NODE_VERSION}" "${USERNAME}" \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Remove library scripts for final image
RUN rm -rf /tmp/library-scripts

# Copy environment.yml (if found) to a temp locaition so we update the environment. Also
# copy "noop.txt" so the COPY instruction does not fail if no environment.yml exists.
COPY environment.yml* .devcontainer/noop.txt /tmp/conda-tmp/
RUN if [ -f "/tmp/conda-tmp/environment.yml" ]; then umask 0002 && /opt/conda/bin/conda env update -n base -f /tmp/conda-tmp/environment.yml; fi \
    && rm -rf /tmp/conda-tmp

# [Optional] Uncomment this section to install additional OS packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>
