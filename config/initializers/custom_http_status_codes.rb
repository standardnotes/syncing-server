# This file is used to define Custom HTTP status codes.
status_code = 498
description = "Expired Access Token"
status_code_symbol = description.parameterize.underscore.to_sym

Rack::Utils::SYMBOL_TO_STATUS_CODE[status_code_symbol] = status_code
Rack::Utils::HTTP_STATUS_CODES[status_code] = description