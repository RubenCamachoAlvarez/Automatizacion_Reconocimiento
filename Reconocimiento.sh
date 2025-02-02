#!/bin/bash
#
#	Autor: Ruben Camacho Alvarez
#
#	Descripcion
#
#	FES_AR@DGTIC
#


DIRECCION_IPv4="$1"

NOMBRE_DIRECTORIO_PRINCIPAL="$2"

RUTA_CREACION="$3"

RUTA_DICCIONARIO=""


#Variable global que almacena el EXIT_CODE retornado al realizar operaciones criticas dentro del script.

EXIT_CODE=0

NUMERO_ARGUMENTOS_SCRIPT="$#"


imprimir_mensaje_error() {

	#Esta funcion es utilizada para imprimir el mensaje recibido como argumento en la salida estandar de errores del sistema.

	echo -e "$1" >&2

}


verificar_exit_code() {

	#Esta funcion se encarga de realizar la operacion o el conjunto de operaciones determinadas para cada tipo de codigo de salida.
	
	#Un valor de codigo de salida diferente de 0 es utilizado para indicar las diferentes razones donde una operaciones critica requerida por este script ha sido ejecutada incorrectamente o no se ha podido realizar.

	if [ $EXIT_CODE -ne 0 ]; then

		echo -en "\n"

		case $EXIT_CODE in

			1) imprimir_mensaje_error "El script ha sido ejecutado sin argumentos." ;;

			2) paquetes_no_instalados=("$@"); error_paquetes_no_instalados "${paquetes_no_instalados[@]}" ;;

			3) imprimir_mensaje_error "El primer argumento ($DIRECCION_IPv4) del script no corresponde con el formato de una direccion IPv4." ;;

			4) imprimir_mensaje_error "Los octetos de la direccion IPv4 '$DIRECCION_IPv4' no pueden ser mayores a 255." ;;

			5) imprimir_mensaje_error "La ruta '$RUTA_CREACION' no existe." ;;

			6) imprimir_mensaje_error "Error al tratar de crear la ruta '$RUTA_CREACION' para almacenar el directorio principal." ;;

			7) imprimir_mensaje_error "La ruta '$RUTA_CREACION' no cuenta con los permisos necesarios para llevar a cabo la creacion del directorio principal." ;;

			8) imprimir_mensaje_error "La ruta '$RUTA_CREACION' no pertenece al usuario que ejecuta el script." ;;

			9) imprimir_mensaje_error "Ya existe un elemento con el nombre de '$NOMBRE_DIRECTORIO_PRINCIPAL' dentro de '$RUTA_CREACION'." ;;

			10) imprimir_mensaje_error "Error al tratar de crear el directorio principal '$NOMBRE_DIRECTORIO_PRINCIPAL' dentro de '$RUTA_CREACION'." ;; 


			11) imprimir_mensaje_error "Es necesario ejecutar este script con permisos de superusuario para poder usar algunas opciones del comando NMAP utilizadas dentro de este script." ;;


		esac

		echo -en "\n"

		exit $EXIT_CODE

	fi


}

verificar_paquetes_instalados() {

	#Esta funcion tiene el objetivo de verificar si el sistema tiene instalados los paquetes de 'nmap', 'ffuf' y 'sectlists'.
	#En caso de que un paquete no este instalado, se ira agregando al arreglo que guarda el nombre de los paquetes.
	#Finalmente, si se tiene algun elemento en este arreglo se indicara un codigo de salida 2, y se volvera a llamar a la funcion para que genere el error correspondiente.
	
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

		if [ "$RUTA_DICCIONARIO" == "" ] || ( ! [ -d "$RUTA_DICCIONARIO" ]); then

			paquetes_no_instalados+=("seclists")

		else

			echo "Diccionarios del paquete seclists ubicados en la ruta: $ruta_diccionarios_seclists"

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

	imprimir_mensaje_error "\nError: Los siguientes paquetes no se encuentran instalados en el sistema.\n"

	paquetes_no_instalados=("$@")

	for nombre_paquete in ${paquetes_no_instalados[@]}; do

		echo "> $nombre_paquete"

	done

}

verificar_permisos_superusuario() {

	if [ "$EUID" -ne 0  ]; then

		echo -e "\nEste script no ha sido ejecutado como usuario 'root' y se necesita permisos de superusuario para poder utilizar caracteristicas avanzadas de NMAP para poder llevar a cabo el escaneo de redes."

		echo -e "\nDebido a esto, tu usuario debe de tener permisos de sudo. Si el usuario '$(whoami)' cuenta con este permiso, ingresa tu contraseña para proceder\n"

		if ! sudo -l > /dev/null 2>&1 ; then

			EXIT_CODE=11

			verificar_exit_code

		fi

	fi

}

verificar_argumentos_script() {

	#Esta funcion es utilizada para verificar los argumentos con los que ha sido invocado este script.
	
	if [ $NUMERO_ARGUMENTOS_SCRIPT -eq 0 ]; then

		#En caso de que el script haya sido invocado sin argumento, entonces asignamos 1 como codigo de salida.

		EXIT_CODE=1

	fi

	#Llamada a la funcion 'verificar_exit_code'.

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

		if [ opcion == "s" ] || [ opcion == "S" ]; then

			return 0

		elif [ opcion == "n" ] || [ opcion == "n" ]; then

			return 1

		fi

	done

}

verificar_ruta_creacion_directorio() {

	if ! [ -d "$RUTA_CREACION" ]; then

		#El directorio no existe.
		
		#Pedir confirmacion para su creacion.
		
		if solicitar_confirmacion_operacion "El directorio $RUTA_CREACION NO existe. ¿Desea intentar crearlo?"; then

			#Si se ha confirmado la creacion de la ruta principal, entonces tratamos de realizar su creacion por medio del comando mkdir -p

			if ! mkdir -p "$RUTA_CREACION"; then

				#Si el codigo de salida producido por mkdir es 1, indicando que la operacion no pudo completarse, entonces generamos
				#el error indicando que fue imposible llevar a cabo la creacion de la ruta en cuestion y terminamos la ejecucion.

				EXIT_CODE=6

				verficar_exit_code

			fi
		
		else:

			#Si es rechazado el intento de creacion de la ruta, entonces simplemente generamos el error indicando que la ruta donde
			#debe de crearse el directorio principal NO existe.

			EXIT_CODE=5

			verificar_exit_code
			

		fi

	elif ! ([ -x "$RUTA_CREACION" ] || [ -w "$RUTA_CREACION" ]); then

		#El directorio existe pero no se tienen permisos de ejecucion o escritura para continuar con la ejecucion del script.
		
		#Si bien lo ideal seria solicitar al usuario la confirmacion para volver a llevar a cabo la creacion de la ruta, la verdad
		#es que esto podria ser perjudicial al solo pedir la confirmacion para literalmente borrar un directorio que podria
		#contener cualquier tipo de informacion relevante. Por ende, en este caso solo terminamos la ejecucion del script indicando
		#el error y dejando al usuario de borrar de manera manual o no el directorio o la cadena de directorios para que estos tengan
		#los permisos apropiados, o simplemente volver a ejecutar el script con una ruta diferente.

			EXIT_CODE=7

			verificar_exit_code

	fi

	
	ruta_final="$RUTA_CREACION/$NOMBRE_DIRECTORIO_PRINCIPAL"

	if [ -e "$ruta_final" ]; then

		#Si ya existe un elemento con el nombre del directorio principal indicado como segundo argumento, entonces generamos el error y terminamos
		#la ejecucion del script.
		
		#Nuevamente por motivos de seguridad dejamos toda la responsabilidad al usuario de llevar a cabo la eliminacion manual de los elementos
		#ya existentes en caso de querer usar dicho nombre para la creacion del directorio principal.

		EXIT_CODE=9

		verificar_exit_code

	else

		#En caso de que no exista un elemento con el nombre del directorio principal solicitado, tratamos de llevar a cabo la creacion
		#del directorio principal.
		
		if [ -w "$RUTA_CREACION" ]; then

			if ! mkdir "$NOMBRE_DIRECTORIO_PRINCIPAL"; then

				#En caso de que mkdir no hay realizado la operacion de creacion del directorio correctamente, entonces esto al usuario mediante
				#un error.
			

				EXIT_CODE=10

				verificar_exit_code


			fi

		else

			EXIT_CODE=7

			verificar_exit_code


		fi


	fi	


}

creacion_subdirectorios() {

	ruta="$RUTA_CREACION/$NOMBRE_DIRECTORIO_PRINCIPAL"

	cd "$ruta"

	mkdir recon exploit content

}


escaneos_NMAP() {


	echo -e "\nREALIZANDO ESCANEO DE PUERTOS CON NMAP\n"

	sudo nmap -sT -p- --open -Pn -n -vvv -oG recon/puertos.txt $DIRECCION_IPv4

	echo -e "\nRECABANDO INFORMACION DE LOS SERVICIOS USANDO NMAP\n"

	sudo nmap -sCV -n -vvv -Pn -oN recon/nmap.txt $DIRECCION_IPv4

}

analisis_escaneos() {

	echo -e "\nBUSCANDO PUERTOS CON SERVICIOS HTTP\n"


	export puertos_servicios=$(grep -E 'Ports: ' recon/puertos.txt | grep -Eo '[0-9]{1,}([a-zA-Z]|/)+http[a-zA-Z]*' | cut -d '/' -f1,5 | tr '\n' ' ' | sed -E 's/ $//g')

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

			ffuf -u $protocolo://$DIRECCION_IPv4:$puerto/FUZZ -w $ruta_diccionarios_seclists/Discovery/Web-Content/raft-large-words-lowercase.txt -t 150 -c

		done

	fi

}


imprimir_informacion_script() {

	echo -e "\nINFORMACION DEL SCRIPT\n"

	echo "Direccion IPv4 del equipo objetivo: $DIRECCION_IPv4"

	echo "Nombre del directorio principal que debe de ser creado: $NOMBRE_DIRECTORIO_PRINCIPAL"

	echo "Ruta donde debe de ser creado el directorio principal: $RUTA_CREACION"

}

bucle_principal_script() {

	verificar_permisos_superusuario

	imprimir_informacion_script
	
	verificar_paquetes_instalados

	verificar_argumentos_script

	verificar_direccion_IPv4

	# verificar_ruta_creacion_directorio

	# creacion_subdirectorios

	# escaneos_NMAP
	

	cd "$RUTA_CREACION/$NOMBRE_DIRECTORIO_PRINCIPAL"
	
	analisis_escaneos

	proceso_fuzzing


}

bucle_principal_script
