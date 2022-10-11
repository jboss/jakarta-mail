#!/bin/bash
#
# Copyright (c) 2018, 2022 Oracle and/or its affiliates. All rights reserved.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License v. 2.0, which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# This Source Code may also be made available under the following Secondary
# Licenses when the conditions for such availability set forth in the
# Eclipse Public License v. 2.0 are satisfied: GNU General Public License,
# version 2 with the GNU Classpath Exception, which is available at
# https://www.gnu.org/software/classpath/license.html.
#
# SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0


# This script will run the Jakarta Mail standalone TCK against a local build of Jakarta Mail API
# To run it:
# $ cd standalone-tck
# $ ./run-jakarta-mail-tck.sh
#
# To test with a different version of Jakarta Activation use the following
# export JAF_BUNDLE_URL=https://repository.jboss.org/nexus/content/groups/public/jakarta/activation/jakarta.activation-api/2.1.1.jbossorg-1/jakarta.activation-api-2.1.1.jbossorg-1.jar
# $ ./run-jakarta-mail-tck.sh


# Requirements:
# - You need docker installed and running
# - You have build a local build of Jakarta Mail API
#


WGET='wget -q --no-check-certificate --tries=100'
WORKSPACE=/tmp/standalone-tck
CURRENT_DIR=$(pwd)

if [ -d "${WORKSPACE}" ]; then
  rm -rf ${WORKSPACE} 2>/dev/null
fi

mkdir ${WORKSPACE}
mkdir ${WORKSPACE}/libs

if [ -z "${JAVA_HOME}" ]; then
  echo "JAVA_HOME is not configured"
  exit 1
fi

export JDK_HOME=$JAVA_HOME
export PATH=$JDK_HOME/bin:$PATH

java -version

if [ -z "$JAF_BUNDLE_URL" ];then
  export JAF_BUNDLE_URL=https://repo1.maven.org/maven2/jakarta/activation/jakarta.activation-api/2.1.0/jakarta.activation-api-2.1.0.jar
fi
if [ -z "$ANGUS_JAF_BUNDLE_URL" ];then
  export ANGUS_JAF_BUNDLE_URL=https://repo1.maven.org/maven2/org/eclipse/angus/angus-activation/1.0.0/angus-activation-1.0.0.jar
fi
if [ -z "$ANGUS_MAIL_BUNDLE_URL" ];then
  export ANGUS_MAIL_BUNDLE_URL=https://repo1.maven.org/maven2/org/eclipse/angus/angus-mail/1.0.0/angus-mail-1.0.0.jar
fi
if [ -z "$MAIL_API_UNDER_TEST" ];then
  export MAIL_API_UNDER_TEST="${CURRENT_DIR}/../api/target/jakarta.mail-api-2.1.2-SNAPSHOT-jbossorg-1.jar"
  if [ ! -f "${MAIL_API_UNDER_TEST}" ]; then
    echo "Jakarta Mail API jar file not found in ${MAIL_API_UNDER_TEST}"
    exit 1
  fi
fi

# TCK
if [ -z "$MAIL_TCK_BUNDLE_URL" ];then
  export MAIL_TCK_BUNDLE_URL=https://download.eclipse.org/jakartaee/mail/2.1/jakarta-mail-tck-2.1.0.zip
fi

cd ${WORKSPACE}
$WGET -O libs/jakarta.activation-api.jar $JAF_BUNDLE_URL
$WGET -O libs/angus-activation.jar $ANGUS_JAF_BUNDLE_URL
$WGET -O libs/angus-mail.jar $ANGUS_MAIL_BUNDLE_URL
cp ${MAIL_API_UNDER_TEST} ${WORKSPACE}/libs/jakarta.mail-api.jar

$WGET -O jakarta-mail-tck-2.1.0.zip ${MAIL_TCK_BUNDLE_URL}
unzip -d . jakarta-mail-tck-2.1.0.zip

$WGET -O apache-ant-1.10.12-bin.zip https://dlcdn.apache.org/ant/binaries/apache-ant-1.10.12-bin.zip
unzip -d . apache-ant-1.10.12-bin.zip

export TS_HOME=${WORKSPACE}/mail-tck
export ANT_HOME=${WORKSPACE}/apache-ant-1.10.12

$WGET https://repo1.maven.org/maven2/ant-contrib/ant-contrib/1.0b3/ant-contrib-1.0b3.jar
mv ant-contrib-1.0b3.jar "$ANT_HOME/lib"


export PATH=$TS_HOME/bin:$ANT_HOME/bin:$PATH
echo "*********************************************************"
echo JAVA_HOME = $JAVA_HOME
echo ANT_HOME = $ANT_HOME
echo PATH = $PATH
echo TS_HOME = $TS_HOME
echo WORKSPACE = $WORKSPACE
echo "*********************************************************"

JAVA_OPTS="-Xms512m -Xmx800m -XX:MaxPermSize=512m -Xss1m -XX:+HeapDumpOnOutOfMemoryError -XX:-UseGCOverheadLimit -Dtest.ejb.stateful.timeout.wait.seconds=70 -Djava.net.preferIPv4Stack=true -Dorg.jboss.resolver.warning=true -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"
JAVA_OPTS="$JAVA_OPTS -Djboss.modules.system.pkgs=$JBOSS_MODULES_SYSTEM_PKGS -Djava.awt.headless=true"

# update ts.jte

cd $TS_HOME

JARPATH=${WORKSPACE}/libs
sed -i "s%JARPATH=.*%JARPATH=${JARPATH}%g" "$TS_HOME/lib/ts.jte"

API_JAR=${WORKSPACE}/libs/jakarta.mail-api.jar:${WORKSPACE}/libs/jakarta.activation-api.jar
sed -i "s%API_JAR=.*%API_JAR=${API_JAR}%g" "$TS_HOME/lib/ts.jte"

CI_JAR=${WORKSPACE}/libs/angus-mail.jar:${WORKSPACE}/libs/angus-activation.jar
sed -i "s%CI_JAR=.*%CI_JAR=${CI_JAR}%g" "$TS_HOME/lib/ts.jte"

sed -i "s%JAVA_HOME=.*%JAVA_HOME=${JAVA_HOME}%g" "$TS_HOME/lib/ts.jte"
sed -i "s%TS_HOME=.*%TS_HOME=${TS_HOME}%g" "$TS_HOME/lib/ts.jte"

MAIL_PASSWORD=1234
MAIL_USER=user01@james.local
MAIL_USER_MAIL_URL_ENCODED=user01%40james.local
SMTP_DOMAIN=james.local
MAIL_HOST=localhost
IMAP_PORT=1143
SMTP_PORT=1025
SMTP_FROM=$MAIL_USER
SMTP_TO=$MAIL_USER
SMTP_DOMAIN=james.local

sed -i "s#^JARPATH=.*#JARPATH=$JARPATH#g" "$TS_HOME/lib/ts.jte"
sed -i "s#^JAVAMAIL_SERVER=.*#JAVAMAIL_SERVER=$MAIL_HOST -pn $IMAP_PORT#g" "$TS_HOME/lib/ts.jte"
sed -i "s#^JAVAMAIL_PROTOCOL=.*#JAVAMAIL_PROTOCOL=imap#g" "$TS_HOME/lib/ts.jte"
sed -i "s#^JAVAMAIL_TRANSPORT_PROTOCOL=.*#JAVAMAIL_TRANSPORT_PROTOCOL=smtp#g" "$TS_HOME/lib/ts.jte"
sed -i "s#^JAVAMAIL_TRANSPORT_SERVER=.*#JAVAMAIL_TRANSPORT_SERVER=$MAIL_HOST -tpn $SMTP_PORT#g" "$TS_HOME/lib/ts.jte"
sed -i "s#^JAVAMAIL_USERNAME=.*#JAVAMAIL_USERNAME=$MAIL_USER#g" "$TS_HOME/lib/ts.jte"
sed -i "s#^JAVAMAIL_PASSWORD=.*#JAVAMAIL_PASSWORD=$MAIL_PASSWORD#g" "$TS_HOME/lib/ts.jte"
sed -i "s#^SMTP_DOMAIN=.*#SMTP_DOMAIN=$SMTP_DOMAIN#g" "$TS_HOME/lib/ts.jte"
sed -i "s#^SMTP_FROM=.*#SMTP_FROM=$SMTP_FROM#g" "$TS_HOME/lib/ts.jte"
sed -i "s#^SMTP_TO=.*#SMTP_TO=$SMTP_TO#g" "$TS_HOME/lib/ts.jte"

sed -i 's%$testDebug% %g' "$TS_HOME/lib/ts.jte"


# ---------------------------------------------------------------------------
# Stop the container in case the Job is stopped or at the end
# ---------------------------------------------------------------------------

function cleanup {
    echo "Cleaning up resources ...."
    docker stop cts-mailserver
    exit 1
}

trap cleanup EXIT SIGTERM SIGINT

cd ${WORKSPACE}
# ---------------------------------------------------------------------------
# launch.sh launches the Apache James and adds a mark to know when it's done
# ---------------------------------------------------------------------------

cat > launch.sh<<EOF
#!/bin/bash
set -x

echo "touch /root/done.mark" >> /root/initialdata.sh

/root/startup.sh | tee /root/mailserver.log
EOF

# ---------------------------------------------------------------------------
# The Docker file we use for Apache James
# ---------------------------------------------------------------------------

cat > Dockerfile<<EOF
FROM linagora/james-jpa-sample:3.0.1

ADD launch.sh /root

RUN chgrp -R 0 /root /logs /var && \
    chmod -R g=u /root /logs /var && \
    chmod +x /root/launch.sh && \
    sed -i s/:143/:1143/g /root/conf/imapserver.xml && \
    sed -i s/:993/:1993/g /root/conf/imapserver.xml && \
    sed -i s/:110/:1110/g /root/conf/pop3server.xml && \
    sed -i s/:25/:1025/g /root/conf/smtpserver.xml && \
    sed -i s/:465/:1465/g /root/conf/smtpserver.xml && \
    sed -i s/:587/:1587/g /root/conf/smtpserver.xml

ENTRYPOINT ["/root/launch.sh"]
EOF

docker build -t jakartaee/wfly-tck-mailserver:1.0 -f Dockerfile .

docker stop cts-mailserver
docker run -d --rm --name cts-mailserver \
  -p "1465:1465" \
  -p "1993:1993" \
  -p "1025:1025" \
  -p "1110:1110" \
  -p "1587:1587" \
  -p "1143:1143" \
docker.io/jakartaee/wfly-tck-mailserver:1.0

for (( l=0; l<=30; l++ ))
do
    echo "Waiting for mail server to be ready ................. $l"
    docker exec cts-mailserver cat /root/done.mark
    if [ "$?" == "0" ]; then
      docker exec cts-mailserver cat /root/mailserver.log
      echo "Mail Server started and it is ready"
      l=30
    fi
    sleep 4
done


# ---------------------------------------------------------------------------
# Populate the mail boxes
# ---------------------------------------------------------------------------

echo "javac fpopulate.java"
cd $TS_HOME/tests/mailboxes

impl=angus-mail.jar
api=jakarta.mail-api.jar
activationimpl=angus-activation.jar
activationapi=jakarta.activation-api.jar

export CLASSPATH=$JARPATH/$activationimpl:$JARPATH/$activationapi:$JARPATH/$impl:$JARPATH/$api:./:$CLASSPATH
echo "CLASSPATH=$CLASSPATH"

javac fpopulate.java
echo "run java fpopulate"
#java fpopulate -D -s test1 -d smtp://nobody:password@localhost/
# -f == force recreation of test data for each test run
# -D = show debug info
java fpopulate -f -s test1 -d "imap://$MAIL_USER_MAIL_URL_ENCODED:$MAIL_PASSWORD@$HOST:$IMAP_PORT"


# ---------------------------------------------------------------------------
# run the tests
# ---------------------------------------------------------------------------
echo "run tests"

cd  $TS_HOME

ant run
