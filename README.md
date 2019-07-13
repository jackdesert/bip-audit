BIP Audit (Code Sample)
=======================

This repository comprises all the pieces that were added to BIPWeb
in order to provide an audit of one particular resident.

Audit in this sense meaning a searchable list of all the records we have
stored for that resident.


Why Provide an Audit?
---------------------

A legal request was made of the facility to produce a list of all records in BIP
for a particular resident in electronic format. In hindsight, they probably
would have been satisfied with


Why is it Build as a Web Page?
------------------------------

Ideally, the opposing lawyers would probably like to have all the data zipped
up and presented as a file archive. But to do that would require choosing
digital formats for data that is already well formatted inside our website.

Therefore the audit returns links to all the digital documents we have,
so they can view them directly on the website.



Why Only One Resident?
----------------------

It would be interesting to store a resident_id in elasticsearch
so we could open up search to all residents. But in favor of YAGNI,
the ask was only for one resident in order to comply with legal requests.



Why Not Update ElasticSearch Every Time New Data is Saved?
----------------------------------------------------------

The resident in question only lived at the facility until 2016,
so no new records are being added at this time. Therefor, a rake task to
populate ElasticSearch suffices.










