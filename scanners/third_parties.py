import logging
import json
import os
import re

from utils import utils
from utils.known_services import known_services

# Evaluate third party service usage using Chrome headless.
#
# If data exists for a domain from `pshtt`, it:
# * will not run if the domain is used only to redirect externally
# * otherwise, will run using the "canonical" URL.
#
#
# Options:
#
# * --timeout: Override default timeout of 60s.
# * --affiliated: A suffix (e.g. ".gov", "twimg.com") known to
#       be affiliated with the scanned domains.
#
# Looks for known, affiliated, and unknown services.

# Categories/Fields:
#
# * All external domains: All unique external domains that get pinged.
# * All subdomains: All unique subdomains that get pinged.
#
# * Affiliated domains: Service domains known to be affiliated.
# * Unknown domains: Any other external service domains.
#
# * [Known Service]: True / False

default_timeout = 60

# TODO: Move Lambda default (./headless_shell) to other place.
command = os.environ.get("CHROMIUM_PATH", "./headless_shell")

# Advertise Lambda support
lambda_support = True


def init_domain(domain, environment, options):
    # If we have data from pshtt, skip if it's not a live domain.
    if utils.domain_not_live(domain):
        logging.debug("\tSkipping, domain not reachable during inspection.")
        return False

    # If we have data from pshtt, skip if it's just a redirector.
    if utils.domain_is_redirect(domain):
        logging.debug("\tSkipping, domain seen as just an external redirector during inspection.")
        return False

    # To scan, we need a URL, not just a domain.
    url = None
    if not (domain.startswith('http://') or domain.startswith('https://')):

        # If we have data from pshtt, use the canonical endpoint.
        if utils.domain_canonical(domain):
            url = utils.domain_canonical(domain)

        # Otherwise, well, whatever.
        else:
            url = 'http://' + domain
    else:
        url = domain

    return {'url': url}


def scan(domain, environment, options):
    timeout = int(options.get("timeout", default_timeout))

    url = environment["url"]

    raw = utils.scan(
        [
            "./scanners/headless/third_parties.js",
            url
        ]
    )

    if not raw:
        logging.warn("\tError with the chromium headless command, skipping.")
        return None

    # TODO: real output
    logging.warn(raw)
    data = raw

    return services_for(url, data, domain, options)


# Gets the return value of scan(), convert to a CSV row.
def to_rows(services):
    return [[
        services['url'], len(services['external'])
    ]]


headers = [
    'Scanned URL',
    'Number of External Domains'
]


# Given a response from the script we gave to Chrome headless,
def services_for(url, data, domain, options):
    services = {
        'url': url,
        'external': list(known_services.keys())
    }
    return services

