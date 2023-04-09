$.ajax({
    url: "/api/comments/",
    type: "GET",
    contentType: "application/json; charset=utf-8"
  }).then(function (response) {
    var dataToReturn = [];
    for (var i=0; i < response.length; i++) {
      var tagToTransform = response[i];
      var newTag = {
                     id: tagToTransform["name"],
                     text: tagToTransform["name"]
                   };
      dataToReturn.push(newTag);
    }
    $("#comments").select2({
      placeholder: "Select Comments for the Post",
      tags: true,
      tokenSeparators: [','],
      data: dataToReturn
    });
  });
