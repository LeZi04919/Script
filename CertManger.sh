#!/usr/bin/bash
Version="1.0"
Cert_Folder="${HOME}/Cert"
CA_PATH="${HOME}/Cert/CA/CA.pem"
CA_Key_PATH="${HOME}/Cert/CA/CA.key"
mCA_PATH="${HOME}/Cert/CA/mCA.pem"
mCA_Key_PATH="${HOME}/Cert/CA/mCA.key"
CONFIG_PATH="${HOME}/.CertificateScriptConfig"
CA_STATUS=false
mCA_STATUS=false
CA_EndDay=0
mCA_EndDay=0
#--------------------------------------------------------
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[INFO]${Font_color_suffix}"
Error="${Red_font_prefix}[ERROR]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[WARNING]${Font_color_suffix}"
#--------------------------------------------------------
ReadConfig()
{
    if [ ! -e "${HOME}/Cert/CA" ];then
        mkdir "${HOME}/Cert/CA"
    fi
    if [ ! -e "${HOME}/Cert" ];then
        mkdir "${HOME}/Cert"
    fi
    #if [ -e ${CONFIG_PATH} ]; then
    #    for line in $(cat ${CONFIG_PATH}); do
    #        if [ -n $(echo ${line} |grep "CA_PATH" ) ]; then
    #            CA_PATH=$(echo ${line} |awk -F '=' '{print $2}')
    #        fi
    #        if [ -n $(echo ${line} |grep "CA_Key_PATH" ) ]; then
    #            CA_Key_PATH=$(echo ${line} |awk -F '=' '{print $2}')
    #        fi
    #        if [ -n $(echo ${line} |grep "mCA_PATH" ) ]; then
    #            mCA_PATH=$(echo ${line} |awk -F '=' '{print $2}')
    #        fi
    #        if [ -n $(echo ${line} |grep "mCA_Key_PATH" ) ]; then
    #            mCA_Key_PATH=$(echo ${line} |awk -F '=' '{print $2}')
    #        fi
    #    done
    #fi
}
CheckCert()
{
    
    if [ -e ${CA_PATH} ] && [ -e ${CA_Key_PATH} ];then
        CA_STATUS=true
    fi
    if [ -e ${mCA_PATH} ] && [ -e ${mCA_Key_PATH} ];then
        mCA_STATUS=true
    fi

    if [ $CA_STATUS = true ];then
        GetCertEndDate "${CA_PATH}" "CA"
    fi
    if [ $mCA_STATUS = true ];then
        GetCertEndDate "${mCA_PATH}" "mCA"
    fi
    
}
GetCertEndDate()
{
    EndDate=$(openssl x509 -text -noout -enddate -in $1|awk 'END {print}')
    Day=$(echo ${EndDate}|awk -F '=' '{print $2}'|awk -F ' ' '{print $2}'|awk '{printf("%02d\n",$0)}')
    Month=$(echo ${EndDate}|awk -F '=' '{print $2}'|awk -F ' ' '{print $1}')
    Year=$(echo ${EndDate}|awk -F '=' '{print $2}'|awk -F ' ' '{print $4}')
    if [ -n $(echo ${line} |grep "Jan") ];then
        Month="01"
    elif [ -n $(echo ${line} |grep "Feb") ];then
        Month="02"
    elif [ -n $(echo ${line} |grep "Mar") ];then
        Month="03"
    elif [ -n $(echo ${line} |grep "Apr") ];then
        Month="04"
    elif [ -n $(echo ${line} |grep "May") ];then
        Month="05"
    elif [ -n $(echo ${line} |grep "Jun") ];then
        Month="06"
    elif [ -n $(echo ${line} |grep "Jul") ];then
        Month="07"
    elif [ -n $(echo ${line} |grep "Aug") ];then
        Month="08"
    elif [ -n $(echo ${line} |grep "Sep") ];then
        Month="09"
    elif [ -n $(echo ${line} |grep "Oct") ];then
        Month="10"
    elif [ -n $(echo ${line} |grep "Nov") ];then
        Month="11"
    elif [ -n $(echo ${line} |grep "Dec") ];then
        Month="12"
    fi
        
    EndDate=$(date +%s -d ${Year}${Month}${Day})
    Date=$(date +%s)
    if [ $2 == "CA" ];then
        a=$(expr $EndDate - $Date)
        b=$(expr $a / 86400)
        CA_EndDay=$b
    else
        a=$(expr $EndDate - $Date)
        b=$(expr $a / 86400)
        mCA_EndDay=$b
    fi
}
CreatRootCert()
{
    openssl req -x509 -newkey rsa -outform PEM -out ${CA_PATH} -keyform PEM -keyout ${CA_Key_PATH} -days $5 -nodes -subj "/C=$1/O=$2/OU=$3/CN=$4"
    if [ $? -eq 0 ];then
        echo -e "${Info}Root CA证书创建成功"
        Main
    else
        echo -e "${Error}Root CA证书创建失败"
    fi
}
CreatMiddleCert()
{
    openssl req -newkey rsa:2048 -outform PEM -out ${HOME}/Cert/CA/intermCA.csr -keyform PEM -keyout ${mCA_Key_PATH} -nodes -extensions v3_ca -config /usr/lib/ssl/openssl.cnf -subj "/C=$1/O=$2/OU=$3/CN=$4"
    openssl x509 -req -days $5 -in ${HOME}/Cert/CA/intermCA.csr -out ${mCA_PATH} -CA ${CA_PATH} -CAkey ${CA_Key_PATH} -CAcreateserial -extensions v3_ca -extfile /usr/lib/ssl/openssl.cnf
    if [ $? -eq 0 ];then
        echo -e "${Info}中间CA证书创建成功"
        Main
    else
        echo -e "${Error}中间CA证书创建失败"
    fi
}
CreatSubCert()
{
    openssl req -newkey rsa:2048 -outform PEM -out ${Cert_Folder}/$4.csr -keyform PEM -keyout ${Cert_Folder}/$4.key -nodes -reqexts SAN -extensions v3_req -config <(cat /usr/lib/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=DNS:$4")) -subj "/C=$1/O=$2/OU=$3/CN=$4"
    openssl x509 -req -days $5 -in ${Cert_Folder}/$4.csr -out ${Cert_Folder}/$4.pem -CA ${mCA_PATH} -CAkey ${mCA_Key_PATH} -CAcreateserial -extensions SAN -extfile <(cat /usr/lib/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=DNS:$4"))
    rm -rf ${Cert_Folder}/$4.csr
    if [ $? -eq 0 ]; then
        echo -e "${Info}证书创建成功"
        Main
    else
        echo -e "${Error}证书创建失败"
    fi
}
InputInformation()
{
    if [[ $1 == "CA" ]] && [[ $CA_STATUS = true ]];then
        echo -e "${Error}您的根CA证书尚且健在!"
        exit 0
    elif [[ $1 == "mCA" ]] && [[ ! CA_STATUS ]];then
        echo -e "${Error}您的根CA证书不存在!"
        exit 0
    elif [[ $1 == "mCA" ]] && [[ $mCA_STATUS = true ]];then
        echo -e "${Error}您的中间CA证书尚且健在!"
        exit 0
    fi

    read -e -p "请输入目标证书的CN值(通用名):" CN
    read -e -p "请输入目标证书的OU值(组织单位):" OU
    read -e -p "请输入目标证书的O值(组织名):" O
    read -e -p "请输入目标证书的C值(国家):" C
    read -e -p "请输入目标证书的有效期(天):" Days

    if [[ $1 == "CA" ]];then
        CreatRootCert "${C}" "${O}" "${OU}" "${CN}" "${Days}"
    elif [[ $1 == "mCA" ]];then
        CreatMiddleCert "${C}" "${O}" "${OU}" "${CN}" "${Days}"
    else
        CreatSubCert "${C}" "${O}" "${OU}" "${CN}" "${Days}"
    fi

}
Main()
{
    ReadConfig
    CheckCert
    echo && echo -e " 
证书签发和管理脚本 ${Red_font_prefix}[v${Version}]${Font_color_suffix}
-- LeZi | leziblog.cn --

———————————  根证书  ———————————
${Green_font_prefix}0.${Font_color_suffix} 签发
——————————— 中间证书 ———————————
${Green_font_prefix}1.${Font_color_suffix} 签发
——————————— 其他证书 ———————————
${Green_font_prefix}2.${Font_color_suffix} 签发
     "
    if [ $CA_STATUS = true ];then
        echo -e "根证书:${Green_font_prefix}可用,${Font_color_suffix}有效期剩余${CA_EndDay}天"
    else
        echo -e "根证书:${Red_font_prefix}不可用${Font_color_suffix}"
    fi
    if [ $mCA_STATUS = true ];then
        echo -e "中间证书:${Green_font_prefix}可用,${Font_color_suffix}有效期剩余${mCA_EndDay}天"
    else
        echo -e "中间证书:${Red_font_prefix}不可用${Font_color_suffix}"
    fi
    echo -e "${Tip}请确保你的系统已安装OpenSSL!" && echo
    read -e -p " 请输入数字 [0-5]:" num
    case "$num" in
	    0)
	    InputInformation "CA"
	    ;;
	    1)
	    InputInformation "mCA"
	    ;;
	    2)
	    InputInformation
	    ;;
	    *)
	    echo "请输入正确数字 [0-5]"
	    ;;
    esac
}
clear
Main