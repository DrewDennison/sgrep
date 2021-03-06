## sgrep build

FROM ocaml/opam2:alpine@sha256:4c2ce9a181b4b12442a68fc221d0b753959ec80e24eae3bf788eeca4dcb9a293 as build-sgrep
USER root
RUN apk add --no-cache perl m4

USER opam
WORKDIR /home/opam/opam-repository
RUN git pull && opam update && opam switch 4.07 && opam install ocamlfind camlp4 num ocamlgraph json-wheel conf-perl dune yaml
WORKDIR /home/opam/

RUN git clone https://github.com/returntocorp/pfff
RUN eval $(opam env) && cd pfff && ./configure && make depend && make && make opt && make install-libs

COPY --chown=opam . /home/opam/sgrep/

RUN eval $(opam env); cd sgrep; make all
RUN /home/opam/sgrep/_build/default/bin/main_sgrep.exe -version

## sgrep lint build

FROM alpine:3.11.3@sha256:ddba4d27a7ffc3f86dd6c2f92041af252a1f23a8e742c90e6e1297bfa1bc0c45 as build-sgrep-lint
RUN apk add --no-cache python3-dev build-base chrpath
COPY . /home/pythonbuild/sgrep/
# have to manually specify colorama for some reason, but others (yaml, etc) are working ok
WORKDIR /home/pythonbuild/sgrep
RUN make lint
RUN ls -al /home/pythonbuild/sgrep/sgrep_lint/build/sgrep.dist/

## final output, combining both

FROM alpine:3.11.3@sha256:ddba4d27a7ffc3f86dd6c2f92041af252a1f23a8e742c90e6e1297bfa1bc0c45
LABEL maintainer="sgrep@r2c.dev"

ENV PYTHONUNBUFFERED=1

COPY --from=build-sgrep-lint /home/pythonbuild/sgrep/sgrep_lint/build/sgrep.dist/* /bin/sgrep-lint-files/
RUN ln -s /bin/sgrep-lint-files/sgrep-lint /bin/sgrep-lint

RUN ls -al  /bin/sgrep-lint-files/cacert.pem
RUN mkdir /bin/sgrep-lint-files/certifi/
RUN ln -sfn /bin/sgrep-lint-files/cacert.pem  /bin/sgrep-lint-files/certifi/cacert.pem
RUN ls -al /bin/sgrep-lint-files/

RUN sgrep-lint --help
COPY --from=build-sgrep /home/opam/sgrep/_build/default/bin/main_sgrep.exe /bin/sgrep
RUN sgrep --help
RUN sgrep-lint --config=r2c /bin/sgrep-lint-files/


ENV SGREP_IN_DOCKER=1
ENTRYPOINT [ "/bin/sgrep-lint" ]
