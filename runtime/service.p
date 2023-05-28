/*
   Copyright 2021 Robert Jervis

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */
/**
 * Provides facilities for defining either a single-instance, replicated
 * stateless or clustered Web service, configuring it, managing it's
 * internal state, monitoring
 * activity, logging events and supplying strategies for high
 * availability.
 */
namespace parasol:service;

import parasol:http;
/**
 * This class defines the global properties of the service, including it's
 * configuration, monitoring, logging, local state and high availability
 * strategies.
 *
 * This class is defined as a monitor class to facilitate coordination
 * among service request threads.
 */
public monitor class WebService<class Configuration, class Monitoring, class Logging, class State, class HighAvailability> {
	/**
	 * Construct the server.
	 *
	 * @param serviceID
	 */
	public WebService(string serviceID) {
		
	}
}
/**
 * This stub class declares that the service has no local configuration file.
 */
public class NoConfiguration {
	/**
	 * Specifices whether this service has any local configuration.
	 *
	 * @return Always false. A service using this as its configuration definition
	 * has no local configuration.
	 */
	public static boolean hasConfiguration() {
		return false;
	}
}
/**
 * All Web services with configuration files must define the structure and storage scheme
 * of their configuration with a class derived from this one.
 */
public class Configuration {
	/**
	 * Specifices whether this service has any local configuration.
	 *
	 * @return Always true. A service using this as its configuration definition
	 * has some local configuration.
	 */
	public static boolean hasConfiguration() {
		return true;
	}
}
/**
 * This stub class delcares that the service has no monitoring.
 */
public class NoMonitoring {
}
/**
 * This stub class declares that the service has no logging.
 */
public class NoLogging {
}
/**
 * THIs stub class declares that the service has no local state.
 */
public class NoState {
}
/**
 * This stub class declares that the service is not highly available.
 */
public class NoHighAvailability {
}

public class HACluster {
}


