#!/bin/bash
#
#	Autor: Ruben Camacho Alvarez
#
#	Descripcion: Este script esta diseñado para automatizar el proceso de reconocimiento aplicado a un
#	a un equipo que sea de interés para el usuario.
#	De esta manera, este script se encarga de crear el directorio principal donde a su vez son creados
#	los subdirectorios 'recon', 'exploit' y 'content'. Posteriormente realiza el escaneo de puertos y
#	descubrimiento de servicios que estén en dicho puertos y finalmente si se encuentra un servidor HTTP o
#	HTTPS en escucha por medio de un puerto abierto del equipo objetivo, se aplica un proceso de fuzzing
#	para tratar de descubrir las rutas disponibles para acceder a recursos que proporciona dicho servidor
#	HTTP.
#
#	Finalmente algo importante aclarar, cualquier elemento que al ejecutar el script genere un conflicto
#	para que el script concluya con su ejecucion, debe de ser manualmente eliminado por el usuario
#	previo a la ejecicion de este script para evitar cualquier perdida de informacion de manera no
#	intencionada. Un ejemplo de esto es el que exista ya la ruta especifica un directorio con el mismo
#	nombre especificado como argumento por el usuario.
#
#	Si bien este proceso de eliminacion podria hacerse por medio de una confirmacion en este script,
#	la realidad es que al ser este un script para dummies, es bastante riesgoso dejar en manos del script
#	la eliminacion completa de directorios y subdirectorios simplemente solicitando una confirmacion
#	para realizar esta operacion a un usuario novato o que incluso a un usuario experimentado por despiste
#	se le pueda olvidar que en el directorio indicado tiene informacion importante.
#
#	Para mitigar este potencial peligro es que el script hay identificar estos conflictos, finaliza la
#	ejecucion del script y le indica con un mensaje cual es el error que manualmente el usuario debe
#	de atender antes de volver a ejecutar el script.
#
#	Esto no solo aplica para el caso de las rutas a recursos, sino tambien si no se tienen instalados
#	los paquetes necesarios instalados en el sistema, etc.
#
#	Fecha de entrega: 02 de Febrero de 2025.
#
#	FES_AR@DGTIC
#

INVOCACION_SCRIPT="$0"

DIRECCION_IPv4="$1"

RUTA_DIRECTORIO_PRINCIPAL="$2"

RUTA_DICCIONARIO="$3"

RUTA_DIRECTORIOS_PADRE=""

NOMBRE_DIRECTORIO_PRINCIPAL=""

EXIT_CODE=0

NUMERO_ARGUMENTOS_SCRIPT="$#"

imprimir_ayuda_script() {

	echo -e "\nAUTOMATIZACION DE PROCESO DE RECONOCIMIENTO\n"

	echo -e "\nFuncion: Este script esta diseñado para poder realizar el proceso de reconocimiento de un equipo objetivo previo a realizar un proceso de pentest.\n"

	echo "Este script en un principio comienza creando un directorio principal donde posteriormente realiza la creacion de los subdirectorios 'recon', 'exploit' y 'content'."

	echo "Posteriormente se realiza un escaneo de puertos utilizando NMAP."

	echo "Si se identifica en los resultados del escaneo que el equipo objetivo tiene un puerto abierto donde este escuchando un servidor HTTP, entonces se usa FFUF para intentar descubrir las rutas disponibles."

	echo -e "\nModo de invocacion:\n"

	echo -e "bash $INVOCACION_SCRIPT direccion_ipv4 ruta_creacion_directorio_principal [ruta_archivo_diccionario]\n\n"

	echo -e "De este modo, si queremos ejecutar este script para un equipo con la direccion IPv4 192.168.25.30 y queremos realizar la creacion del directorio principal en /home/user/ con el nombre de 'escaneo', ejecutariamos el comando de la siguiente manera.\n"

	echo -e "bash $INVOCACION_SCRIPT 192.168.25.30 /home/user/escaneo\n\n"

	echo -e "Del mismo modo, si queremos ahora tambien indicar que use como diccionario el archivo 'diccionario.txt' que se encuentra en el directorio padre del directorio donde se ejecuta este comando, hariamos la invocacion del comando de la siguiente manera.\n"

	echo -e "bash $INVOCACION_SCRIPT 192.168.25.30 /home/user/escaneo ../diccionario.txt\n"

	echo -e "\nEn ambos casos, tanto para indicar la ruta donde se creara el directorio del escaneo, como para indicar la ruta del archivo que sera usado como diccionario, pueden indicarse por medio de rutas absolutas o relativas.\n"

	echo -e "\nNOTA IMPORTANTE: Cuando se indica la ruta (con el nombre) del directorio que se va a crear por este script, el script realiza previamente un análisis para conocer si los directorios padres ya existen.\n"

	echo "En caso de que estos directorios padres no existan el script intenta realizar su creacion automaticamente."

	echo "Del mismo modo, se encarga de verificar que el nombre del directorio (ultimo token de la ruta) no se encuentre previamente creado. En caso de ya existir un elemento con ese nombre dentro de la ruta indicada, el script termina su ejecucion abruptamente, muestra el error al usuario y ES RESPONSABILIDAD DEL USUARIO LLEVAR A CABO EL PROCESO DE ELIMINACION DE DICHO DIRECTORIO/ELEMENTO si quiere asignarle dicho nombre al directorio que crea este script."

	echo -e "Esta medida esta hecha para mitigar cualquier posibilidad de borrar informacion importante y que en caso de querer hacerlo EL USUARIO LO HAGA MANUALMENTE.\n"

	echo -e "\nNOTA 2: Si este script no es ejecutado como root, el usuario que lo ejecuta debe de tener permisos de sudo, ya que al principio se solicita ingresar la contraseña para verificarlo y poder realizar la ejecucion correcta de las opciones de nmap que requieren permisos de superusuario.\n"
	
	echo -e "\nNOTA 3: Si no se especifica una ruta del archivo de diccionario a utilizar, el script por defecto utiliza el diccionario /Discovery/Web-Content/raft-small-words-lowercase.txt que se encuentra dentro de la ruta del paquete seclists al ser instalado con el gestor de paquetes del sistema.\n"

}


imprimir_mensaje_error() {

	echo -e "$1" >&2

}


verificar_exit_code() {

	if [ $EXIT_CODE -ne 0 ]; then

		echo -en "\n"

		case $EXIT_CODE in

			1) imprimir_mensaje_error "El script ha sido ejecutado sin argumentos."; imprimir_ayuda_script;;

			2) paquetes_no_instalados=("$@"); error_paquetes_no_instalados "${paquetes_no_instalados[@]}" ;;

			3) imprimir_mensaje_error "El primer argumento ($DIRECCION_IPv4) del script no corresponde con el formato de una direccion IPv4." ;;

			4) imprimir_mensaje_error "Los octetos de la direccion IPv4 '$DIRECCION_IPv4' no pueden ser mayores a 255." ;;
			
			5) imprimir_mensaje_error "El argumento '$RUTA_DIRECTORIO_PRINCIPAL' no corresppnde a una ruta valida en el sistema de archivos para la creacion del directorio principal." ;;
			
			6) imprimir_mensaje_error "El argumento '$RUTA_DICCIONARIO' no corresponde a una ruta valida al archivo que sera utilizado como diccionario." ;;

			7) imprimir_mensaje_error "La ruta '$RUTA_DIRECTORIOS_PADRE' no existe." ;;

			8) imprimir_mensaje_error "Error al tratar de crear la ruta '$RUTA_DIRECTORIOS_PADRE' para almacenar el directorio principal." ;;

			9) imprimir_mensaje_error "La ruta '$RUTA_DIRECTORIOS_PADRE' no cuenta con los permisos necesarios para llevar a cabo la creacion del directorio principal." ;;

			10) imprimir_mensaje_error "La ruta '$RUTA_DIRECTORIOS_PADRE' no pertenece al usuario que ejecuta el script." ;;

			11) imprimir_mensaje_error "Ya existe un elemento con el nombre de '$NOMBRE_DIRECTORIO_PRINCIPAL' dentro de '$RUTA_DIRECTORIOS_PADRE'." ;;

			12) imprimir_mensaje_error "Error al tratar de crear el directorio principal '$NOMBRE_DIRECTORIO_PRINCIPAL' dentro de '$RUTA_DIRECTORIOS_PADRE." ;;


			13) imprimir_mensaje_error "Es necesario ejecutar este script con permisos de superusuario para poder usar algunas opciones del comando NMAP utilizadas dentro de este script." ;;
 
 			14) imprimir_mensaje_error "La ruta del diccionario a utilizar '$RUTA_DICCIONARIO' no corresponde a un archivo." ;;

			15) imprimir_mensaje_error "Error al tratar de crear los subdirectorios dentro de '$RUTA_DIRECTORIO_PRINCIAL'" ;;

			16) imprimir_mensaje_error "El script debe de ser invocado con al menos 2 argumentos: direccion IPv4 del equipo destino y la ruta o nombre del directorio principal que se creará" ;;


		esac

		echo -en "\n"

		exit $EXIT_CODE

	fi


}

verificar_paquetes_instalados() {
	
	echo -e "\nVERIFICANDO LOS PAQUETES INSTALADOS\n"

	paquete_no_instalados=()

	if ! which nmap > /dev/null 2>&1; then

		paquetes_no_instalados+=("nmap")

	else

		echo "nmap ubicado en la ruta: $(which nmap)" 

	fi



	if ! which ffuf > /dev/null 2>&1; then

		paquetes_no_instalados+=("ffuf")

	else

		echo "ffuf ubicado en la ruta: $(which ffuf)"


	fi
	
	if [ "$RUTA_DICCIONARIO" == "" ]; then

		RUTA_DICCIONARIO=$(locate seclists | head -n 1)

		if [ "$RUTA_DICCIONARIO" == "" ]; then

			paquetes_no_instalados+=("seclists")

		else

			echo "Diccionarios del paquete seclists ubicados en la ruta: $RUTA_DICCIONARIO"
			
			RUTA_DICCIONARIO="$RUTA_DICCIONARIO/Discovery/Web-Content/raft-small-words-lowercase.txt"

		fi
		
	else
	
		echo "Ruta del diccionario a utilizar: $RUTA_DICCIONARIO"
		
	fi



	if [ "${#paquetes_no_instalados[@]}" -gt 0 ]; then

		EXIT_CODE=2

		verificar_exit_code "${paquetes_no_instalados[@]}"

	fi

}

error_paquetes_no_instalados() {

	imprimir_mensaje_error "\nPAQUETES NO INSTALADOS\n"
	
	imprimir_mensaje_error "Los siguientes paquetes no se encuentran instalados en el sistema.\n"

	paquetes_no_instalados=("$@")

	for nombre_paquete in ${paquetes_no_instalados[@]}; do

		imprimir_mensaje_error "> $nombre_paquete"

		if [ "$nombre_paquete" == "seclists" ]; then

			imprimir_mensaje_error "\nPuede que el sistema no haya podido detectar correctamente el paquete '$nombre_paquete'."

			imprimir_mensaje_error "Si usted está seguro de que lo tiene instalado, entonces ingrese como tercer argumento la ruta al diccionario de seclists que desea utilizar.\n"

		fi

	done

}

verificar_permisos_superusuario() {

	echo -e "\nVERIFICANDO PERMISOS DE SUPERUSUARIO\n"

	if [ "$EUID" -ne 0  ]; then

		echo -e "Este script no ha sido ejecutado como usuario 'root' y se necesita permisos de superusuario para poder utilizar caracteristicas avanzadas de NMAP para poder llevar a cabo el escaneo de redes."

		echo -e "\nDebido a esto, tu usuario debe de tener permisos de sudo. Si el usuario '$(whoami)' cuenta con este permiso, ingresa tu contraseña para proceder\n"

		if ! sudo -l > /dev/null 2>&1 ; then

			EXIT_CODE=11

			verificar_exit_code

		fi

	fi

}

verificar_argumentos_script() {

	if [ $NUMERO_ARGUMENTOS_SCRIPT -eq 0 ]; then

		EXIT_CODE=1
		
	else

		if [ "$NUMERO_ARGUMENTOS_SCRIPT" -ge 2 ]; then
	
			if ! echo "$RUTA_DIRECTORIO_PRINCIPAL" | grep -qE '^/{0,1}((\.{1,2}|[a-zA-Z0-9_-]+)/)*[a-zA-Z0-9_-]+$'; then

				EXIT_CODE=5

			else

				RUTA_DIRECTORIOS_PADRE=$(echo "$RUTA_DIRECTORIO_PRINCIPAL" | grep -Eo '^/{0,1}((\.{1,2}|[a-zA-Z0-9_-]+)/)*')

				if [ "$RUTA_DIRECTORIOS_PADRE" == "" ]; then

					RUTA_DIRECTORIOS_PADRE="."

				fi

				NOMBRE_DIRECTORIO_PRINCIPAL=$(echo "$RUTA_DIRECTORIO_PRINCIPAL" | grep -Eo '[a-zA-Z0-9_-]+$')

			fi

			if [ "$RUTA_DICCIONARIO" != "" ]; then

				if ! echo "$RUTA_DICCIONARIO" | grep -qE '^/{0,1}((\.{1,2}|[a-zA-Z0-9_-]+)/)*[a-zA-Z0-9_-]+(\.[a-zA-Z0-9]+)*$'; then

					EXIT_CODE=6

				elif ! [ -f "$RUTA_DICCIONARIO" ]; then

					EXIT_CODE=13

				fi

			fi

		else

			EXIT_CODE=16


		fi
	

	fi

	verificar_exit_code

}


verificar_direccion_IPv4() {

	if ! (echo "$DIRECCION_IPv4" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'); then

		EXIT_CODE=3

		verificar_exit_code

	else

		octetos=$DIRECCION_IPv4

		IFS_ORIGINAL="$IFS"

		IFS="."

		for octeto in $octetos; do

			if [ $octeto -gt 255 ]; then

				EXIT_CODE=4

				verificar_exit_code

			fi
			
		done

		IFS="$IFS_ORIGINAL"

	fi

}

solicitar_confirmacion_operacion() {

	while true; do

		echo "$1 [s/n]: "

		read opcion

		if [ "$opcion" == "s" ] || [ "$opcion" == "S" ]; then

			return 0

		elif [ "$opcion" == "n" ] || [ "$opcion" == "n" ]; then

			return 1

		fi


	done

}

verificar_ruta_creacion_directorio() {

	if ! [ -d "$RUTA_DIRECTORIOS_PADRE" ]; then
		
		if solicitar_confirmacion_operacion "La ruta '$RUTA_DIRECTORIOS_PADRE' NO existe. ¿Desea intentar crearla?"; then

			if ! mkdir -p "$RUTA_DIRECTORIOS_PADRE"; then

				EXIT_CODE=8

				verficar_exit_code

			fi

		else

			EXIT_CODE=7

			verificar_exit_code

		fi

	elif ! [ -x "$RUTA_DIRECTORIOS_PADRE" ] || ! [ -w "$RUTA_DIRECTORIOS_PADRE" ]; then

			EXIT_CODE=9

			verificar_exit_code

	fi

	
	

	if [ -e "$RUTA_DIRECTORIO_PRINCIPAL" ]; then

		EXIT_CODE=11

		verificar_exit_code

	else
		
		if [ -w "$RUTA_DIRECTORIOS_PADRE" ]; then

			if ! mkdir "$RUTA_DIRECTORIO_PRINCIPAL"; then
			
				EXIT_CODE=12

				verificar_exit_code


			fi

		else

			EXIT_CODE=9

			verificar_exit_code


		fi


	fi	


}

creacion_subdirectorios() {

	if ! mkdir $RUTA_DIRECTORIO_PRINCIPAL/recon $RUTA_DIRECTORIO_PRINCIPAL/exploit $RUTA_DIRECTORIO_PRINCIPAL/content; then

		EXIT_CODE=15

		verificar_exit_code

	fi

}


escaneos_NMAP() {


	echo -e "\nREALIZANDO ESCANEO DE PUERTOS CON NMAP\n"

	sudo nmap -sT -p- --open -Pn -n -vvv -oG $RUTA_DIRECTORIO_PRINCIPAL/recon/puertos.txt $DIRECCION_IPv4

	echo -e "\nRECABANDO INFORMACION DE LOS SERVICIOS USANDO NMAP\n"

	sudo nmap -sCV -n -vvv -Pn -oN $RUTA_DIRECTORIO_PRINCIPAL/recon/nmap.txt $DIRECCION_IPv4

}

analisis_escaneos() {

	echo -e "\nBUSCANDO PUERTOS CON SERVICIOS HTTP\n"


	export puertos_servicios=$(grep -E 'Ports: ' $RUTA_DIRECTORIO_PRINCIPAL/recon/puertos.txt | grep -Eo '[0-9]{1,}([a-zA-Z]|/)+http[a-zA-Z]*' | cut -d '/' -f1,5 | tr '\n' ' ' | sed -E 's/ $//g')

	echo "Puertos abiertos con servicios HTTP: $puertos_servicios"


}

proceso_fuzzing() {

	echo -e "\nEJECUTANDO PROCESO DE FUZZING\n"

	if [ puertos != "" ]; then

		IFS_original="$IFS"

		IFS=" "

		for datos in $puertos_servicios; do

			puerto=$(echo "$datos" | cut -d'/' -f1)

			protocolo=$(echo "$datos" | cut -d'/' -f2)

			ffuf -u $protocolo://$DIRECCION_IPv4:$puerto/FUZZ -w $RUTA_DICCIONARIO -t 150 -c -s

		done
		
		IFS="$IFS_original"

	fi

}


imprimir_datos_operacion() {

	echo -e "\nDATOS DE OPERACION\n"

	echo "Direccion IPv4 del equipo objetivo: $DIRECCION_IPv4"

	echo "Nombre del directorio principal que debe de ser creado: $NOMBRE_DIRECTORIO_PRINCIPAL"

	echo "Ruta donde debe de ser creado el directorio principal: $RUTA_DIRECTORIOS_PADRE"

}

bucle_principal_script() {

	if [ "$NUMERO_ARGUMENTOS_SCRIPT" -eq 0 ]; then

		EXIT_CODE=1

		verificar_exit_code

	fi

	verificar_permisos_superusuario
	
	verificar_paquetes_instalados

	verificar_argumentos_script

	verificar_direccion_IPv4

	verificar_ruta_creacion_directorio
	
	imprimir_datos_operacion

	creacion_subdirectorios

	escaneos_NMAP
	
	analisis_escaneos

	proceso_fuzzing

	echo "HA CONCLUIDO EL PROCESO SATISFACTORIAMENTE."

}

bucle_principal_script
