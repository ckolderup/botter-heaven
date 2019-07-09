class Wikimedia
  WIKI_API_URL_BASE = 'https://commons.wikimedia.org/w/api.php'

  WIKI_RANDOM_IMAGE_PARAMS = {
    action: 'query',
    list: 'random',
    gcmtitle: 'Category:Photographs_of_people',
    gcmtype: 'file',
    gcmnamespace: 6,
    generator: 'categorymembers',
    format: 'json'
  }

  WIKI_IMAGE_INFO_PARAMS = {
    action: 'query',
    prop: 'imageinfo',
    indexpageids: nil,
    pageids: nil,
    iiprop: 'url',
    iiurlwidth: 1000,
    format: 'json'
  }

  def self.fetch_random_image
    search_result_response = RestClient.get WIKI_API_URL_BASE, params: WIKI_RANDOM_IMAGE_PARAMS
    search_result = JSON.parse(search_result_response.to_str)
    image_id = search_result['query']['random'].first['id']

    id_response = RestClient.get WIKI_API_URL_BASE, params: WIKI_IMAGE_INFO_PARAMS.merge(pageids: image_id)
    image_result = JSON.parse(id_response.to_str)

    image_info = image_result['query']['pages'].values.first['imageinfo']

    if image_info.is_a?(Array)
      image_info.first['url']
    elsif image_info.is_a?(Hash)
      image_info['url']
    else
      nil
    end
  end
end
