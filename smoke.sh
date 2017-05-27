#!/bin/bash -xe

set -e

CNONE=''
CRED='[ERROR]'
CGREEN='[DEBUG]'
C0=$CNONE

SMOKE_TYPE=""
DEPLOY_SMOKE=0
DEPLOY_BILL=0
ALL_DEPLOY=0
SMOKE_BRANCH="develop"
SMOKE_ENV=""
OPENSTACK_IP=""
BILL_IP=""
FUEL_SMOKE_PATH="/home/smoke"
INIT_FILE="SMOKEENV.ini"

jWorkDir="/home/jenkins"
jMountDir="/home/jenkins/data"
jGetTempestConfScript="get_tempest_conf.py"
jSshpass="sshpass"
jDeployEnv="deploy_env.sh"
jEnvdiskConfScript="config_fuel_disk.py"
jBillDeploy="bill_deploy.py"
jGetPublicIp="get_public_ip.py"
jEnvConfig="config_env_test.sh"
jImageDistribution="check_image_distribution.py"
jDemoConfig="demo_config_for_tempest.sh"
FuelDeploy="/home/smoke/deploy_env/deploy_env.rb"
FuelConfigEnv="/home/smoke/deploy_env/config_env.sh"

trap sigterm_handler TERM
sigterm_handler() {
	echo "They use TERM to bring us down. No such luck."
	return
}

usage() {
	cat <<END
	-f or --fuel_ip {ip}   fuel ip
	-s or --smoke_name [name] fuel smoke name}
	-b or --bill_name [name]  fuel bill name
	-t or --smoke_type {smoke|full-smoke}  smoke_type
	-t or --smoke_branch [name]  smoke git branch
	--deploy_smoke  deploy openstack
	--deploy_bill   deploy bill center
END
	exit 1
}

#打印错误代码并退出
die()
{
	ecode=$1;
	shift;	
	echo -e "${CRED}$*, exit $ecode${C0}";
	exit $ecode;
}

ldebug()
{
	echo -e "${CGREEN}$*${C0}";
}

#解析参数
param_parse()
{
	# 可输入的选项参数设置
	ARGS=`getopt -a -o t:b:e -l smoke_type:,smoke_branch:,smoke_env:,all_deploy,deploy_smoke,deploy_bill -- "$@"`
	[ $? -ne 0 ] && usage

	eval set -- "${ARGS}"
	while true
	do
		case "$1" in
		-t|--smoke_type)
			SMOKE_TYPE="$2"
			shift
			;;
		-b|--smoke_branch)
			SMOKE_BRANCH="$2"
			shift
			;;
		-e|--smoke_env)
			SMOKE_ENV="$2"
			shift
			;;
		--deploy_smoke)
			DEPLOY_SMOKE=1
			;;
		--deploy_bill)
			DEPLOY_BILL=1
			;;
		--all_deploy)
			ALL_DEPLOY=1
			;;
		-h|--help)
			usage
			;;
		--)
			shift  
			break
			;;  
			esac  
	shift
	done
}

function copyfile2workdir()
{
	rm -rf $jWorkDir/$jEnvConfig
	cp -rf $jMountDir/$jEnvConfig $jWorkDir/$jEnvConfig

	rm -rf $jWorkDir/$jImageDistribution
	cp -rf $jMountDir/$jImageDistribution $jWorkDir/$jImageDistribution

	rm -rf $jWorkDir/$jDemoConfig
	cp -rf $jMountDir/$jDemoConfig $jWorkDir/$jDemoConfig

	rm -rf $jWorkdir/$jGetTempestConfScript
	cp -rf $jMountDir/$jGetTempestConfScript $jWorkDir/$jGetTempestConfScript
	rm -rf $jWorkdir/$jGetPublicIp
	cp -rf $jMountDir/$jGetPublicIp $jWorkDir/$jGetPublicIp

	cp -rf $jMountDir/$jDeployEnv $jWorkDir/$jDeployEnv
	cp -rf $jMountDir/$jEnvdiskConfScript $jWorkDir/$jEnvdiskConfScript

	rm -rf $jWorkDir/$jBillDeploy
	cp -rf $jMountDir/$jBillDeploy $jWorkDir/$jBillDeploy

	rm -rf $jWorkDir/$INIT_FILE
	cp -rf $jMountDir/$INIT_FILE $jWorkDir/$INIT_FILE
}

function readini()
{
	ini_file=$jWorkDir/$INIT_FILE

	section=$1
	key=$2

	# 判断变量key是否为空 如果为空 显示该[]下的所有字段
	if [ "$key" = "" ];then
	   sed -n "/\[$section\]/,/\[.*\]/{
		   /^\[.*\]/d
		   /^[ ]*$/d
		   s/;.*$//
		   p
		   }" $ini_file
	else
	   sed -n "/\[$section\]/,/\[.*\]/{
		   /^\[.*\]/d
		   /^[ ]*$/d
		   s/;.*$//
		   s/^[ |    ]*$key[|    ]*=[ |    ]*\(.*\)[ |    ]*/\1/p
		   }" $ini_file
	fi
}

export_env_var()
{
	section="smoke_comenv"
    com_env_var=$(readini $section)
    for var in $com_env_var
    do
    	export $var
    done

    smoke_env_var=$(readini $SMOKE_ENV)
    for var in $smoke_env_var
    do
    	export $var
    done

}

# deploy_env()
# {
# 	if [ $DEPLOY_SMOKE -eq 1 ]; then
# 		if [ "$PKG_NAME" == "" ];then
# 			$FUEL_SSH_CMD /etc/puppet/modules/vt-cloud/update-online.sh $PKG_VERSION>/dev/null 2>&1
# 			$FUEL_SSH_CMD /etc/puppet/modules/vt-cloud/update-online.sh $PKG_VERSION>/dev/null 2>&1
# 		else
# 			$FUEL_SSH_CMD /etc/puppet/modules/vt-cloud/update-online.sh $PKG_NAME $PKG_VERSION>/dev/null 2>&1
# 			$FUEL_SSH_CMD /etc/puppet/modules/vt-cloud/update-online.sh $PKG_NAME $PKG_VERSION>/dev/null 2>&1
# 		fi
# 	fi
# # 	if [ "$PKG_NAME" != "" -a $DEPLOY_SMOKE -eq 1 ]; then
# # 		$FUEL_SSH_CMD /etc/puppet/modules/vt-cloud/update-online.sh $PKG_NAME>/dev/null 2>&1
# # 		$FUEL_SSH_CMD /etc/puppet/modules/vt-cloud/update-online.sh $PKG_NAME>/dev/null 2>&1
# # 	fi
#
# 	if [ "$SMOKE_NAME" != "" -a $DEPLOY_SMOKE -eq 1 ]; then
# 		ldebug "begin to deploy fuel_name = $SMOKE_NAME, fuel ip = $FUEL_IP"
# 		$FUEL_SSH_CMD bash -x $FUEL_SMOKE_PATH/$jDeployEnv "$SMOKE_NAME"
# 		ldebug "success to deploy fuel_name = $SMOKE_NAME, fuel ip = $FUEL_IP"
# 	fi
#
# 	if [ "$BILL_NAME" != "" -a $DEPLOY_BILL -eq 1 ]; then
# 		ldebug "begin to deploy fuel_name = $BILL_NAME, fuel ip = $FUEL_IP"
# 		$FUEL_SSH_CMD bash -x $FUEL_SMOKE_PATH/$jDeployEnv "$BILL_NAME"
# 		ldebug "success to deploy fuel_name = $BILL_NAME, fuel ip = $FUEL_IP"
# 	fi
#
# 	if [ "$WEB_NAME" != "" ]; then
# 		ldebug "begin to deploy fuel_name = $WEB_NAME, fuel ip = $FUEL_IP"
# 		$FUEL_SSH_CMD bash -x $FUEL_SMOKE_PATH/$jDeployEnv "$WEB_NAME"
# 		ldebug "success to deploy fuel_name = $WEB_NAME, fuel ip = $FUEL_IP"
# 	fi
#
# }

# deploy_all()
# {
# 	if [ $ALL_DEPLOY -eq 1 ]; then
# 		ldebug "begin to deploy all fuel ip = $FUEL_IP"
# 		deploy_env $*
# 		$FUEL_SSH_CMD $FuelConfigEnv $CONSOLE_NAME $BILL_NAME $WEB_NAME
# 		ldebug "success to deploy all"
#
# 	fi
# }

get_tempest_conf()
{
	ldebug "begin to get tempest config"
	for i in `seq 5`
	do
		if [ "$SMOKE_TYPE" != "bill-smoke" ]; then
			python $jWorkDir/$jGetTempestConfScript "$OPENSTACK_IP"
		else
			python $jWorkDir/$jGetTempestConfScript "$OPENSTACK_IP" "$BILL_IP" "bill"
		fi
		grep DEFAULT $jWorkDir/tempest.conf && break
	done
	grep DEFAULT $jWorkDir/tempest.conf || die 1 "get tempest failed"

	cat $jWorkDir/tempest.conf

	ldebug "success to get tempest config"
}


main()
{
	param_parse $*

	yum install -y ntpdate
	#cp -rf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && ntpdate cn.pool.ntp.org
	curl http://200.200.0.36/cpt/ci/raw/master/pip.conf > ~/.pip/pip.conf

	copyfile2workdir
	export_env_var $*

	FUEL_SSH_CMD="sshpass -p $FUEL_PASSWORD ssh root@$FUEL_IP"
	FUEL_SCP_CMD="sshpass -p $FUEL_PASSWORD scp -r"

	pip list | grep pbr
	pip install pbr --upgrade

	ldebug "begin to install fuelclient"
	pip install -U python-fuelclient

	cp -rf $jMountDir/$jSshpass /bin/
	chmod u+x /bin/sshpass
	mkdir -p /root/.ssh
	echo StrictHostKeyChecking no >>/root/.ssh/config

	$FUEL_SSH_CMD mkdir -p $FUEL_SMOKE_PATH
 	$FUEL_SCP_CMD $jWorkDir/$jDeployEnv root@$FUEL_IP:$FUEL_SMOKE_PATH
 	$FUEL_SCP_CMD $jWorkDir/$jEnvdiskConfScript root@$FUEL_IP:$FUEL_SMOKE_PATH


	#deploy_env $*


	ldebug "begin to get openstack public ip"
	OPENSTACK_IP=`python $jWorkDir/$jGetPublicIp "$FUEL_IP" "$CONSOLE_NAME"`
	if [ "$OPENSTACK_IP" = "" ]; then
		ldebug "get openstack public ip failed"
		exit 1
	fi
	ldebug "success to exec $jWorkDir/$jGetPublicIp, openstack public ip = $OPENSTACK_IP"

	if [ "$SMOKE_TYPE" == "bill-smoke" ]; then
		ldebug "begin to get bill center public ip"
		BILL_IP=`python $jWorkDir/$jGetPublicIp "$FUEL_IP" "$BILL_NAME"`
		if [ "$BILL_IP" == "" ]; then
			ldebug "get bill public ip failed"
			exit 1
		fi
		ldebug "success to exec $jWorkDir/$jGetPublicIp, bill public ip = $BILL_IP"
	fi

	SMOKE_ENV_SSH_CMD="sshpass -p $OPENSTACK_PWD ssh root@$OPENSTACK_IP"
	SMOKE_ENV_SCP_CMD="sshpass -p $OPENSTACK_PWD scp -r"

	BILL_ENV_SSH_CMD="sshpass -p $OPENSTACK_PWD ssh root@$BILL_IP"

	$SMOKE_ENV_SCP_CMD $jWorkDir/$jImageDistribution root@$OPENSTACK_IP:/root/vt-cloud/
	$SMOKE_ENV_SCP_CMD $jWorkDir/$jEnvConfig root@$OPENSTACK_IP:/root/vt-cloud/
	$SMOKE_ENV_SCP_CMD $jWorkDir/$jDemoConfig root@$OPENSTACK_IP:/root/vt-cloud/

# 	$BILL_ENV_SSH_CMD bash -x /root/vt-cloud/billcenter-config.sh $OPENSTACK_IP
#  	$SMOKE_ENV_SSH_CMD bash -x /root/vt-cloud/billcenter-config.sh $BILL_IP

	if [ "$SMOKE_TYPE" != "bill-smoke" ]; then
		if [ "$BULID_ISCSI" == "NO" ];then
			$SMOKE_ENV_SSH_CMD bash -x /root/vt-cloud/$jEnvConfig $CONSOLE_NAME
		else
			$SMOKE_ENV_SSH_CMD bash -x /root/vt-cloud/$jEnvConfig
		fi

		$SMOKE_ENV_SSH_CMD bash -x /root/vt-cloud/$jDemoConfig $OPENSTACK_IP
		$SMOKE_ENV_SSH_CMD python /root/vt-cloud/$jImageDistribution
	fi
#
# 	if [ "$SMOKE_TYPE" == "bill-smoke" -a $DEPLOY_BILL -eq 1 ]; then
# 		$BILL_ENV_SSH_CMD bash -x /root/vt-cloud/billcenter-config.sh $OPENSTACK_IP
# 		$SMOKE_ENV_SSH_CMD bash -x /root/vt-cloud/billcenter-config.sh $BILL_IP
#
# 		if [ "$PKG_NAME" == "trunk" ];then
# 			$BILL_ENV_SSH_CMD  bash -x /root/vt-cloud/init_keystone.sh
# 		fi
# 	fi

	if [ "${SMOKE_TYPE}" != "" -a "$SMOKE_BRANCH" != "" ]; then
		get_tempest_conf $*

		git clone -b $SMOKE_BRANCH http://200.200.0.36/cpt/tempest.git $jWorkDir/tempest
		# copy tempest.conf to tempest/conf
		cp -rf $jWorkDir/tempest.conf $jWorkDir/tempest/etc/tempest.conf
        $SMOKE_ENV_SSH_CMD cp -fr /etc/yum.repos.d/bak/* /etc/yum.repos.d/
		cd $jWorkDir/tempest
		log_file=$jMountDir/logs_smoke/${SMOKE_TYPE}_${BUILD_NUMBER}_tempest.log
		touch $log_file
		ln -s $log_file /tmp/tempest.log
		tox -e${SMOKE_TYPE}
	fi
}

main $*
exit 0
