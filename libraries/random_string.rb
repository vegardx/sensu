def random_string(length=20)
        chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
        password = String.new
	while password.length < length
        	password << chars[rand(chars.size)]
	end
        password
end
