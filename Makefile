index.html: index.bs
	curl https://api.csswg.org/bikeshed/ -F file=@index.bs  > index.html

check: index.bs
	curl https://api.csswg.org/bikeshed/ -F file=@index.bs -F output=err
