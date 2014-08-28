
class Item
	attr_accessor :titulo, :title, :texto, :text, :enlace, :link, :tipo, :tags
	
	def initialize()
		@titulo=nil
		@title=nil
		@texto=nil
		@text=nil
		@enlace=nil
		@link=nil
		@tipo=nil
		@tags=nil
	end

	def setall(titulo,title,texto,text,enlace,link,tipo,tags)
		@titulo=titulo
		@title=title
		@texto=texto
		@text=text
		@enlace=enlace
		@link=link
		@tipo=tipo
		@tags=tags
	end


	def setfromxml(nodes,noden)
		@titulo=(nodes/'./titulo').text	
		@title=(noden/'./titulo').text
		@texto=(nodes/'./texto').text	
		@text=(noden/'./texto').text
		@enlace=(nodes/'./link').text	
		@link=(noden/'./link').text
		@tipo=(nodes/'./tipo').text	
		@tags=(noden/'./tag').text
	end

end