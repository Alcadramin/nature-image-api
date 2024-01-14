require 'agoo'
require 'faraday'
require 'json'

BASE_URL = 'https://www.reddit.com/r/earthporn/search.json?restrict_sr=1&q='

class SearchApi
  def self.search(query, after)
    url = "#{BASE_URL}#{query}"
    url += "&after=#{after}" if after

    response = Faraday.get(url)
    result = JSON.parse(response.body)

    children = result['data']['children']
    after = result['data']['after']

    images = children
              .select { |child| child['data']['url']&.match(/\.(jpg|png|jpeg|bmp|webm)$/) }
              .map { |child|
                data = child['data']
                {
                  title: data['title'].gsub(/\[(.*)\]|\((.*)\)/, '').strip,
                  image: data['url'],
                  thumbnail: data['thumbnail'],
                  author: data['author'],
                  source: "https://www.reddit.com#{data['permalink']}",
                  created_utc: data['created_utc']
                }
              }

    [200, { 'content-type' => 'application/json' }, [{ images: images, after: after }.to_json]]
  end
end

class Handler
  def root(req)
    [200, { 'content-type' => 'application/json' }, [{ message: 'Welcome to the Nature Image Search API. Make a request to /search?q=your-search-term-here' }.to_json]]
  end

  def search(req)
    query_params = req['QUERY_STRING']&.split('&')&.map { |pair| pair.split('=') }&.to_h || {}
    q = query_params['q']
    after = query_params['after']
    result = SearchApi.search(q, after)
    [result[0], { 'content-type' => 'application/json' }, result[2]]
  end

  def not_found(req)
    [404, { 'content-type' => 'application/json' }, [{ error: 'Not Found' }.to_json]]
  end
end

handler = Handler.new

Agoo::Server.init(6464, 'root')
Agoo::Server.handle(:GET, '/', handler.method(:root))
Agoo::Server.handle(:GET, '/search', handler.method(:search))
Agoo::Server.handle(:GET, '/.*', handler.method(:not_found))

Agoo::Server.start()
