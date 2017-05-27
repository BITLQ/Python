#!/bin/bash -xe

set -e

CNONE=''
CRED='[ERROR]'
CGREEN='[DEBUG]'
C0=$CNONE


DEPLOY_CONSOLE=0
DEPLOY_BILL=0
DEPLOY_WEB=0
ALL_DEPLOY=0
RUN_SMOKE=0
QUICK_DEPLOY=0
NO_UPDATE_PACKAGE=0
UPGRATE_WEB=""

DEPLOY_ENV=""
FUEL_IP=""
CONSOLE_NAME=""
BILL_NAME=""
WEB_NAME=""
WEB_DEPLOY_IP=""
FUEL_CONFIG_ENV=""
PKG_VERSION=""
PKG_NAME=""

OPENSTACK_IP=""
WEB_IP=""
BILL_IP=""
FUEL_SMOKE_PATH="/home/smoke"




trap sigterm_handler TERM
sigterm_handler() {
	echo "They use TERM to bring us down. No such luck."
	return
}

usage() {
	cat <<END
	-f or --fuel_ip {ip}   fuel ip
	-s or --CONSOLE_NAME [name] fuel smoke name}
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
	ARGS=`getopt -a -o d:f:c:b:w:p:v:o:e:r:a:u -l deploy_env:,fuel_ip:,console_name:,bill_name:,web_name:,pkg_name:,pkg_version:,console_pwd:,web_deploy_ip:,copy_region_file:,all_init_env:,fuel_conf_env:,all_deploy,quick_deploy,deploy_console,deploy_bill,deploy_web,run_smoke,no_update_package,upgrate_web -- "$@"`
	[ $? -ne 0 ] && usage

	eval set -- "${ARGS}"
	while true
	do
		case "$1" in
		-d|--deploy_env)
			DEPLOY_ENV="$2"
			shift
			;;
		-f|--fuel_ip)
			FUEL_IP="$2";
			shift
			;;
		-c|--console_name)
			CONSOLE_NAME="$2"
			shift
			;;
		-b|--bill_name)
			BILL_NAME="$2";
			shift
			;;
		-w|--web_name)
			WEB_NAME="$2"
			shift
			;;
		-p|--pkg_name)
			PKG_NAME="$2";
			shift
			;;
		-p|--pkg_version)
			PKG_VERSION="$2";
			shift
			;;
		-o|--console_pwd)
			OPENSTACK_PWD="$2"
			BILLCENTER_PWD="$2"
			shift
			;;
		-e|--web_deploy_ip)
			WEB_DEPLOY_IP="$2";
			shift
			;;
		-r|--copy_region_file)
			WEB_COPY_REGION="$2"
			shift
			;;
		-a|--all_init_env)
			ALL_ENV_INIT="$2";
			shift
			;;
		-u|--fuel_conf_env)
			FUEL_CONFIG_ENV="$2";
			shift
			;;
		--deploy_console)
			DEPLOY_CONSOLE=1
			;;
		--deploy_bill)
			DEPLOY_BILL=1
			;;
		--deploy_web)
			DEPLOY_WEB=1
			;;
		--all_deploy)
			ALL_DEPLOY=1
			;;
		--quick_deploy)
			QUICK_DEPLOY=1
			;;
		--run_smoke)
			RUN_SMOKE=1
			;;
		--no_update_package)
			NO_UPDATE_PACKAGE=1
			;;
		--upgrate_web)
			UPGRATE_WEB=1
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

function init_run_env()
{
	yum install -y ntpdate
	#cp -rf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && ntpdate cn.pool.ntp.org
	curl http://200.200.0.36/cpt/ci/raw/master/pip.conf > ~/.pip/pip.conf

	jWorkDir="/home/jenkins"
	jMountDir="/home/jenkins/data"
	jSshpass="sshpass"
	jDeployEnv="deploy_env.sh"
	jGetPublicIp="get_public_ip.py"
	jEnvdiskConfScript="config_fuel_disk.py"
	jEnvConfig="config_env_test.sh"
	jImageDistribution="check_image_distribution.py"
	UcSqlTemp="uc_applications.sql"
	InitAllApps="init_all_apps.sh"
	INIT_FILE="SMOKEENV.ini"
	jDeleteNode="delete_offline_node.py"

	jDemoConfig="demo_config_for_tempest.sh"

	pip list | grep pbr
	pip install pbr --upgrade

	ldebug "begin to install fuelclient"
	pip install -U python-fuelclient

	cp -rf $jMountDir/$jSshpass /bin/
	chmod u+x /bin/sshpass
	mkdir -p /root/.ssh
	echo StrictHostKeyChecking no >>/root/.ssh/config
}

function copyfile2workdir()
{
	cp -rf $jMountDir/$jDeployEnv $jWorkDir/$jDeployEnv
	cp -rf $jMountDir/$jEnvdiskConfScript $jWorkDir/$jEnvdiskConfScript

	rm -rf $jWorkDir/$jEnvConfig
	cp -rf $jMountDir/$jEnvConfig $jWorkDir/$jEnvConfig

	rm -rf $jWorkDir/$jImageDistribution
	cp -rf $jMountDir/$jImageDistribution $jWorkDir/$jImageDistribution

	rm -rf $jWorkdir/$jGetPublicIp
	cp -rf $jMountDir/$jGetPublicIp $jWorkDir/$jGetPublicIp

	rm -rf $jWorkdir/$UcSqlTemp
	cp -rf $jMountDir/$UcSqlTemp $jWorkDir/$UcSqlTemp

	rm -rf $jWorkdir/$InitAllApps
	cp -rf $jMountDir/$InitAllApps $jWorkDir/$InitAllApps

	rm -rf $jWorkDir/$INIT_FILE
	cp -rf $jMountDir/$INIT_FILE $jWorkDir/$INIT_FILE

	rm -rf $jWorkDir/$jDemoConfig
	cp -rf $jMountDir/$jDemoConfig $jWorkDir/$jDemoConfig
}

function readini()
{
	ini_file=$jMountDir/$INIT_FILE

	section=$1
	key=$2
	newvalue=$3

	# 判断变量key是否为空 如果为空 显示该[]下的所有字段
	if [ "$key" = "" ];then
	   sed -n "/\[$section\]/,/\[.*\]/{
		   /^\[.*\]/d
		   /^[ ]*$/d
		   s/;.*$//
		   p
		   }" $ini_file

	elif [ "$newvalue" = "#" ];then
	   sed -n "/\[$section\]/,/\[.*\]/{
		   /^\[.*\]/d
		   /^[ ]*$/d
		   s/;.*$//
		   s/^[ |    ]*$key[|    ]*=[ |    ]*\(.*\)[ |    ]*/\1/p
		   }" $ini_file
	else
		#sed -i "/^\[$section\]$/,/^\[/ s/^$key=*/$key=$newvalue/" $ini_file
		sed -i "/^\[$section\]$/,/^\[/ s/^$key=.*/$key=$newvalue/g" $ini_file

	fi
}


function export_env_var()
{
	section="deploy_comenv"
    com_env_var=$(readini $section)
    for var in $com_env_var
    do
    	export $var
    done

    deploy_env_var=$(readini $DEPLOY_ENV)
    for var in $deploy_env_var
    do
    	export $var
    done


}

function deploy_env()
{

	$FUEL_SSH_CMD mkdir -p $FUEL_SMOKE_PATH
 	$FUEL_SCP_CMD $jWorkDir/$jDeployEnv root@$FUEL_IP:$FUEL_SMOKE_PATH
 	$FUEL_SCP_CMD $jWorkDir/$jEnvdiskConfScript root@$FUEL_IP:$FUEL_SMOKE_PATH


	if [ $NO_UPDATE_PACKAGE -eq 0 ]; then

		if [ $DEPLOY_CONSOLE -eq 1 -o $ALL_DEPLOY -eq 1 -o $QUICK_DEPLOY -eq 1 ]; then
			if [ "$PKG_NAME" == "" ];then
				$FUEL_SSH_CMD /etc/puppet/modules/vt-cloud/update-online.sh $PKG_VERSION>/dev/null 2>&1
				#$FUEL_SSH_CMD /etc/puppet/modules/vt-cloud/update-online.sh $PKG_VERSION>/dev/null 2>&1
			else
				$FUEL_SSH_CMD /etc/puppet/modules/vt-cloud/update-online.sh $PKG_NAME $PKG_VERSION>/dev/null 2>&1
				#$FUEL_SSH_CMD /etc/puppet/modules/vt-cloud/update-online.sh $PKG_NAME $PKG_VERSION>/dev/null 2>&1
			fi
		fi
	fi

	if [ $QUICK_DEPLOY -eq 1 ];then
		for i in $CONSOLE_NAME $BILL_NAME $WEB_NAME
		do
		{
			if [ "$i" != "" ];then
				$FUEL_SSH_CMD bash -x $FUEL_SMOKE_PATH/$jDeployEnv "$i"
			fi
		}&
		done
		wait
	else

		if [ "$CONSOLE_NAME" != "" -a $DEPLOY_CONSOLE -eq 1 -o $ALL_DEPLOY -eq 1 ]; then
			ldebug "begin to deploy fuel_name = $CONSOLE_NAME, fuel ip = $FUEL_IP"
			$FUEL_SSH_CMD bash -x $FUEL_SMOKE_PATH/$jDeployEnv "$CONSOLE_NAME"
			ldebug "success to deploy fuel_name = $CONSOLE_NAME, fuel ip = $FUEL_IP"
		fi

		if [ "$BILL_NAME" != "" -a $DEPLOY_BILL -eq 1 -o $ALL_DEPLOY -eq 1 ]; then
			ldebug "begin to deploy fuel_name = $BILL_NAME, fuel ip = $FUEL_IP"
			$FUEL_SSH_CMD bash -x $FUEL_SMOKE_PATH/$jDeployEnv "$BILL_NAME"
			ldebug "success to deploy fuel_name = $BILL_NAME, fuel ip = $FUEL_IP"
		fi

		if [ "$WEB_NAME" != "" -a $DEPLOY_WEB -eq 1 -o $ALL_DEPLOY -eq 1 ]; then
			ldebug "begin to deploy fuel_name = $WEB_NAME, fuel ip = $FUEL_IP"
			$FUEL_SSH_CMD bash -x $FUEL_SMOKE_PATH/$jDeployEnv "$WEB_NAME"
			ldebug "success to deploy fuel_name = $WEB_NAME, fuel ip = $FUEL_IP"
		fi

	fi

	if [ "$DEPLOY_ENV" == "fty_env" -o "$DEPLOY_ENV" == "org_env" -a "$PKG_NAME" != "trunk" ];then
		env_id_website=$($FUEL_SSH_CMD "fuel env | grep -w $WEB_NAME  | awk '{print \$1}'")
		webips=$($FUEL_SSH_CMD "fuel node --env $env_id_website |grep -E \"controller\" | awk '{print \$10}'")
		for ip in $webips;do
			if [ "$DEPLOY_ENV" == "fty_env" ];then
				$FUEL_SSH_CMD "ssh $ip \"ip r a 200.200.115.90 via 100.83.0.254 dev eth0\" "
			elif [ "$DEPLOY_ENV" == "org_env" ];then
				if [ "$ip" == "172.10.2.22" ];then
					eth="eth4"
				else
					eth="eth0"
				fi
				$FUEL_SSH_CMD "ssh $ip \"ip r a 200.200.115.90 via 172.78.0.1 dev $eth\" "
			fi
		done
	fi

}

function get_env_ip()
{
	if [ "$CONSOLE_NAME" != "" ];then
		ldebug "begin to get openstack public ip"
		OPENSTACK_IP=`python $jWorkDir/$jGetPublicIp "$FUEL_IP" "$CONSOLE_NAME"`
		if [ "$OPENSTACK_IP" = "" ]; then
			ldebug "get openstack public ip failed"
		fi
		ldebug "success to exec $jWorkDir/$jGetPublicIp, openstack public ip = $OPENSTACK_IP"
	fi

	if [ "$WEB_NAME" != "" ];then
		ldebug "begin to get web ip"
		WEB_IP=`python $jWorkDir/$jGetPublicIp "$FUEL_IP" "$WEB_NAME"`
		if [ "$WEB_IP" = "" ]; then
			ldebug "get openstack public ip failed"
		fi
		ldebug "success to exec $jWorkDir/$jGetPublicIp, openstack public ip = $WEB_IP"
	fi
}

function deploy_and_config_env()
{
	FUEL_SSH_CMD="sshpass -p $FUEL_PASSWORD ssh root@$FUEL_IP"
	FUEL_SCP_CMD="sshpass -p $FUEL_PASSWORD scp -r"

	deploy_env $*

	get_env_ip $*

	SMOKE_ENV_SSH_CMD="sshpass -p $OPENSTACK_PWD ssh root@$OPENSTACK_IP"
	SMOKE_ENV_SCP_CMD="sshpass -p $OPENSTACK_PWD scp -r"

# 	if [  "$DEPLOY_ENV" == "cc_env" ]; then
# 		WEB_ENV_SSH_CMD="sshpass -p $OPENSTACK_PWD ssh root@$WEB_IP"
# 		WEB_ENV_SCP_CMD="sshpass -p $OPENSTACK_PWD scp -r"
# 		WEB_FILE_PATH="/etc/puppet/modules/vt-cloud/resources/php7/init_apps"
#
# 		$WEB_ENV_SCP_CMD $jWorkDir/$UcSqlTemp root@$WEB_IP:$WEB_FILE_PATH
# 		$WEB_ENV_SCP_CMD $jWorkDir/$InitAllApps root@$WEB_IP:$WEB_FILE_PATH
# 		$WEB_ENV_SSH_CMD chmod a+x $WEB_FILE_PATH/$InitAllApps
# 	fi

	$SMOKE_ENV_SCP_CMD $jWorkDir/$jImageDistribution root@$OPENSTACK_IP:/root/vt-cloud/
	$SMOKE_ENV_SCP_CMD $jWorkDir/$jEnvConfig root@$OPENSTACK_IP:/root/vt-cloud/

	if [ "$WEB_DEPLOY_IP" != "" ];then
		WEB_DEPLOY_SSH_CMD="sshpass -p $WEB_DEPLOY_PASSWORD ssh root@$WEB_DEPLOY_IP"
		$WEB_DEPLOY_SSH_CMD bash -x $WEB_COPY_REGION
		if [ $UPGRATE_WEB -eq 1 ];then
			$WEB_DEPLOY_SSH_CMD bash -x $DEPLOY_WEB_SH all
		else
			$WEB_DEPLOY_SSH_CMD bash -x $ALL_ENV_INIT
		fi
	fi

	if [ "$DEPLOY_ENV" == "cc_env" -o "$DEPLOY_ENV" == "Trunk_smoke" ]; then
		WEB_ENV_SSH_CMD="sshpass -p $OPENSTACK_PWD ssh root@$WEB_IP"
		$WEB_ENV_SSH_CMD "sed -i  's@ADMIN_LOGIN_ALLOW_HOST=account.int.xyclouds.cn@ADMIN_LOGIN_ALLOW_HOST=account.int.xyclouds.cc@g' /var/www/account/shared/.env"
	fi

	if [ "$DEPLOY_ENV" != "dxp_env" ]; then
		if [ "$BULID_ISCSI" == "NO" ];then
			$SMOKE_ENV_SSH_CMD bash -x /root/vt-cloud/$jEnvConfig $DEPLOY_ENV
			$SMOKE_ENV_SSH_CMD python /root/vt-cloud/$jImageDistribution
			$FUEL_SSH_CMD bash -x $FUEL_CONFIG_ENV
		else
			$SMOKE_ENV_SSH_CMD bash -x /root/vt-cloud/$jEnvConfig
			$SMOKE_ENV_SSH_CMD python /root/vt-cloud/$jImageDistribution
			$FUEL_SSH_CMD bash -x $FUEL_CONFIG_ENV
		fi
	else
		$FUEL_SSH_CMD bash -x $FUEL_CONFIG_ENV
	fi


}


function smoke()
{
	section="Common_smoke"
	readini $section "FUEL_IP" $FUEL_IP
	readini $section "SMOKE_NAME" $CONSOLE_NAME
	readini $section "PKG_NAME" $PKG_NAME
	curl "http://200.200.115.90:8080/view/Common_tempest/job/Common_tempest_run_entry(nodeploy)/build?token=Common_no_deploy_run_entry"
}

main()
{
	param_parse $*

	init_run_env $*

	copyfile2workdir
	export_env_var $*

	deploy_and_config_env $*

	if [ $RUN_SMOKE -eq 1 ];then
		smoke $*
		#deploy_and_config_env $*
	fi
	python $jMountDir/$jDeleteNode

}

main $*
exit 0
