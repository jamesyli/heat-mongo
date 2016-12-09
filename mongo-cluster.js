var cfg = { _id: 'my-mongo-set',
    members: [
        { _id: 0, host: 'mongo-pri:27017'},
        { _id: 1, host: 'mongo-sec1:27017'},
        { _id: 2, host: 'mongo-sec2:27017'}
    ]
};

rs.initiate(cfg);

