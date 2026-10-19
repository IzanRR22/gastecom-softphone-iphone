/*
* Copyright (c) 2010-2023 Belledonne Communications SARL.
*
* This file is part of linphone
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program. If not, see <http://www.gnu.org/licenses/>.
*/
// swiftlint:disable line_length

// Singleton instance that logs both info from the App and from the core, using the core log level. ([app] log_level parameter in linphonerc-factory-app

import UIKit
import os
import linphonesw
import linphone

class Log: LoggingServiceDelegate {
	
	static let instance = Log()
		
#if DEBUG
	var debugEnabled = true // Todo : bind to app parameters
#else
	// Release: las trazas Debug/Trace del core contienen mensajes SIP completos (cabeceras Authorization)
	var debugEnabled = false
#endif
	var service = LoggingService.Instance
	
	let appGroupName: String = {
		Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_NAME") as? String
		?? {
			fatalError("APP_GROUP_NAME not defined in Info.plist")
		}()
	}()

	private init() {
		service.domain = Bundle.main.bundleIdentifier!
		Core.setLogCollectionPath(path: Factory.Instance.getDataDir(context: UnsafeMutablePointer<Int8>(mutating: (self.appGroupName as NSString).utf8String)))
		// En release no se activa: no queremos el fichero de log (mensajes SIP completos) en disco
#if DEBUG
		Core.enableLogCollection(state: LogCollectionState.Enabled)
#endif
		setMask()
		LoggingService.Instance.addDelegate(delegate: self)
		
	}
	
	func setMask() {
		if debugEnabled {
			LoggingService.Instance.logLevelMask = UInt(LogLevel.Fatal.rawValue + LogLevel.Error.rawValue + LogLevel.Warning.rawValue + LogLevel.Message.rawValue + LogLevel.Trace.rawValue + LogLevel.Debug.rawValue)
		} else {
			LoggingService.Instance.logLevelMask = UInt(LogLevel.Fatal.rawValue +  LogLevel.Error.rawValue +  LogLevel.Warning.rawValue)
		}
	}
	
	let levelToStrings: [Int: String] =
		[LogLevel.Debug.rawValue: "Debug"
		 , LogLevel.Trace.rawValue: "Trace"
		 , LogLevel.Message.rawValue: "Message"
		 , LogLevel.Warning.rawValue: "Warning"
		 , LogLevel.Error.rawValue: "Error"
		 , LogLevel.Fatal.rawValue: "Fatal"]
	
	let levelToOSleLogLevel: [Int: OSLogType] =
		[LogLevel.Debug.rawValue: .debug,
		 LogLevel.Trace.rawValue: .info,
		 LogLevel.Message.rawValue: .info,
		 LogLevel.Warning.rawValue: .error,
		 LogLevel.Error.rawValue: .error,
		 LogLevel.Fatal.rawValue: .fault]
	
	public class func debug(_ message: String) {
		instance.service.debug(message: message)
	}
	public class func info(_ message: String) {
		instance.service.message(message: message)
	}
	public class func warn(_ message: String) {
		instance.service.warning(message: message)
	}
	public class func error(_ message: String) {
		instance.service.error(message: message)
	}
	public class func fatal(_ message: String) {
		instance.service.fatal(message: message)
	}
	
	private func output(_ message: String, _ level: Int, _ domain: String = Bundle.main.bundleIdentifier!) {
		let log = "[\(domain)][\(levelToStrings[level] ?? "Unkown")] \(message)\n"
		if #available(iOS 10.0, *) {
			// El formato tiene que ser literal, asi que se elige en compilacion.
			//
			// En Release va como privado: estas lineas llevan URIs SIP, call-ids y
			// numeros de telefono, y con %{public}@ quedaban legibles en Console.app
			// para cualquiera con acceso al equipo — historial de llamadas incluido.
			//
			// Contrapartida asumida: en campo, Console.app mostrara <private>. Para
			// soporte queda el log propio de Linphone en fichero, que si es legible.
			// En Debug se mantiene publico para no estorbar el desarrollo.
			#if DEBUG
			os_log("%{public}@", type: levelToOSleLogLevel[level] ?? .info, log)
			#else
			os_log("%{private}@", type: levelToOSleLogLevel[level] ?? .info, log)
			#endif
		} else {
			NSLog(log)
		}

		// NO se reenvian las lineas de log a ningun servicio externo.
		//
		// output() lo invoca onLogMessageWritten, que es el callback del SDK: por
		// aqui pasa CADA linea del core. En Release la mascara deja pasar
		// Warning/Error/Fatal, que incluyen URIs SIP, call-ids y direcciones
		// locales y remotas. Reenviarlas enviaba metadatos de llamadas de los
		// terminales a Google, contradiciendo el "Sin telemetria Linphone" de la
		// documentacion del proyecto, y con implicaciones de RGPD al salir del
		// ambito europeo.
		//
		// 2026-10-15: Firebase/Crashlytics retirado de la app. No se envian ni
		// trazas de fallo ni logs a terceros.
	}
		
	func onLogMessageWritten(logService: LoggingService, domain: String, level: LogLevel, message: String) {
		output(message, level.rawValue, domain)
	}

	public class func stackTrace() {
		Thread.callStackSymbols.forEach { print($0) }
	}
	
	// Debug
	public class func cdlog(_ message: String) {
		info("cdes>\(message)")
	}
	public class func bmlog(_ message: String) {
		info("bmar>\(message)")
	}
	public class func qelog(_ message: String) {
		info("qarg>\(message)")
	}
		
}

// swiftlint:enable line_length
