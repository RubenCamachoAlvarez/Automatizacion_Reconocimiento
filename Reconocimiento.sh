#!/bin/bash
#
#	Autor: Ruben Camacho Alvarez
#
#	Descripcion: Script que automatiza el proceso de escaneo de puertos abierto, descubrimiento de versiones de los servicios que escuchan en dichos puertos
#	y, en caso de ser necesario, el descubrimiento de rutas si es que algun servidor HTTP se encuentra disponible en el equipo objetivo por medio de alguno puerto abierto.
#
#	FES_AR@DGTIC
#
#

NUMERO_ARGUMENTOS="$#"

NOMBRE_COMANDO="$0"

CODIGO_SALIDA=0

DIRECCION_IPv4="$1"

RUTA_ESPECIFICADA="$2"


imprimir_error() {

	#Esta funcion debe de ser llamada como un unico argumento indicando el error que debe de mostrarse a traves de la salida de errores estandar.
	
	echo "$1" >&2

}

verificar_codigo_salida() {

	if [ "$CODIGO_SALIDA" -ne  0 ]; then

		case $CODIGO_SALIDA in

			1) imprimir_error "Script invocada sin argumentos" ;;

			2) imprimir_error "El primer argumento recibido no corresponde con el formato de una direccion IP." ;;

			3) imprimir_error "Los octetos de la direccion IP solo pueden tener valores entre [0, 255]." ;;

			4) imprimir_error "La ruta especifica como segundo argumento NO corresponde a la ruta de un directorio." ;;

			5) imprimir_error "No se poseen permisos de escritura dentro del directorio especificado" ;;

			6) imprimir_error "Sin permisos de escritura en el directorio padre para crear el directorio de la ruta especificada" ;;

			7) imprimir_error "Sin permisos de ejecucion para ingresar a la ruta solicitada" ;;

		esac

		exit "$CODIGO_SALIDA"

	fi

}


verificar_direccion_IPv4() {

	(! echo $DIRECCION_IPv4 | grep -qE '([0-9]{1,3}\.){3}[0-3]{1,3}') && CODIGO_SALIDA=2

	octetos=$DIRECCION_IPv4

	IFS="."

	for octeto in $octetos; do

		echo "$octeto"

		if ( [ "$octeto" -lt 0 ] || [ "$octeto" -gt 255 ] ); then

			CODIGO_SALIDA=3

			 break

		fi
	
	done

	verificar_codigo_salida

}

verificar_directorio_destino() {

	

}

confirmar_operacion() {

	while true; do
		
		echo "$1 [s\\n]: "

		read opcion

		if [ opcion != "s" ] && [ opcion != "n" ]; then

			imprimir_error "Esta no es una opcion valida."

		else

			[ "$opcion" == "==" ] && return 0 || return 1

			break

		fi

	done

}

verificar_direccion_IPv4
